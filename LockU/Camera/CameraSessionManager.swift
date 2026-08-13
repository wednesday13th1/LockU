import AVFoundation
import Combine
import UIKit

nonisolated enum LockUCameraErrorSeverity: Sendable {
    case recoverable
    case userActionRequired
    case unsupported
    case internalFault
}

nonisolated enum LockUCameraError: LocalizedError {
    case cameraUnavailable
    case inputCreationFailed
    case cannotAddInput
    case cannotAddOutput
    case captureFailed
    case invalidPhotoData
    case dualCaptureFailed
    case cameraPermissionDenied

    var severity: LockUCameraErrorSeverity {
        switch self {
        case .cameraPermissionDenied:
            return .userActionRequired
        case .cameraUnavailable:
            return .unsupported
        case .captureFailed, .dualCaptureFailed:
            return .recoverable
        case .inputCreationFailed, .cannotAddInput, .cannotAddOutput, .invalidPhotoData:
            return .internalFault
        }
    }

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "この端末で利用できるカメラが見つかりません。"
        case .inputCreationFailed:
            return "カメラ入力を準備できませんでした。"
        case .cannotAddInput:
            return "カメラ入力をセッションへ追加できませんでした。"
        case .cannotAddOutput:
            return "写真出力をセッションへ追加できませんでした。"
        case .captureFailed:
            return "写真の撮影に失敗しました。"
        case .invalidPhotoData:
            return "撮影した写真を画像へ変換できませんでした。"
        case .dualCaptureFailed:
            return "前後カメラの同時撮影に失敗しました。もう一度お試しください。"
        case .cameraPermissionDenied:
            return "Dual Cameraを使うには、設定でカメラへのアクセスを許可してください。"
        }
    }
}

nonisolated enum CameraSessionMode: Equatable, Sendable {
    case single
    case dual
}

nonisolated enum DualCameraSessionState: Equatable, Sendable {
    case idle
    case requestingPermission
    case configuring
    case ready
    case starting
    case running
    case stopping
    case stopped
    case interrupted
    case unsupported
    case failed
}

nonisolated enum DualCameraHealth: Equatable, Sendable {
    case unknown
    case starting
    case healthy
    case degraded
    case recovering
    case unavailable
}

nonisolated enum DualCameraUXState: Equatable, Sendable {
    case preparing
    case ready
    case capturing
    case interrupted
    case recovering
    case failed
    case permissionDenied
    case unsupported
}

/// Pure lifecycle policy. It has no AVFoundation dependency, so transition regression tests do
/// not require camera hardware.
nonisolated enum DualCameraStateTransitionPolicy {
    static func permits(from: DualCameraSessionState, to: DualCameraSessionState) -> Bool {
        if from == to { return true }
        if to == .failed || to == .stopping { return true }
        switch from {
        case .idle:
            return to == .requestingPermission || to == .configuring || to == .stopped || to == .unsupported
        case .requestingPermission:
            return to == .configuring || to == .unsupported
        case .configuring:
            return to == .ready
        case .ready:
            return to == .starting || to == .configuring
        case .starting:
            return to == .running || to == .interrupted
        case .running:
            return to == .interrupted
        case .stopping:
            return to == .stopped || to == .starting
        case .stopped:
            return to == .configuring || to == .ready || to == .starting || to == .unsupported
        case .interrupted:
            return to == .starting || to == .stopped
        case .unsupported:
            return to == .stopped
        case .failed:
            return to == .configuring || to == .starting || to == .stopped || to == .unsupported
        }
    }

    #if DEBUG
    static func assertRegressionGuards() {
        assert(!permits(from: .idle, to: .running))
        assert(!permits(from: .configuring, to: .running))
        assert(permits(from: .ready, to: .starting))
        assert(permits(from: .starting, to: .running))
        assert(permits(from: .running, to: .stopping))
        assert(permits(from: .failed, to: .starting))
    }
    #endif
}

nonisolated enum LightExposureCameraRole: Sendable {
    case front
    case back
}

/// Maps user intent to a restrained target-bias range while continuous auto exposure remains in
/// control. The signed power curve gives 40...60% finer precision without sacrificing the ends.
nonisolated enum LockULightExposureMapping {
    private static let curveExponent = 1.65

    static func bias(
        lightLevel: Double,
        deviceMinimum: Float,
        deviceMaximum: Float,
        role: LightExposureCameraRole
    ) -> Float {
        let safeLevel = lightLevel.isFinite ? min(100, max(0, lightLevel)) : 50
        let normalized = (safeLevel - 50) / 50
        let curvedMagnitude = pow(abs(normalized), curveExponent)
        let curved = normalized < 0 ? -curvedMagnitude : curvedMagnitude

        let preferred: ClosedRange<Float>
        switch role {
        case .front:
            // A little less dark and a little more open for faces, while keeping neutral at EV 0.
            preferred = -1.20...1.30
        case .back:
            // Preserve sky/window highlights sooner than the front camera.
            preferred = -1.35...1.10
        }

        let lower = max(deviceMinimum, preferred.lowerBound)
        let upper = min(deviceMaximum, preferred.upperBound)
        guard lower <= upper else { return min(deviceMaximum, max(deviceMinimum, 0)) }

        let rawBias = curved < 0
            ? Double(-lower) * curved
            : Double(upper) * curved
        return min(deviceMaximum, max(deviceMinimum, Float(rawBias)))
    }

    #if DEBUG
    static func assertRegressionGuards() {
        for role in [LightExposureCameraRole.front, .back] {
            let samples = [0, 25, 50, 75, 100].map {
                bias(lightLevel: Double($0), deviceMinimum: -1, deviceMaximum: 1, role: role)
            }
            assert(samples.indices.dropFirst().allSatisfy { samples[$0 - 1] <= samples[$0] })
            assert(abs(samples[2]) < 0.0001)
            assert(samples[0] >= -1 && samples[4] <= 1)
            assert(bias(lightLevel: .nan, deviceMinimum: -1, deviceMaximum: 1, role: role) == 0)
        }
    }
    #endif
}

nonisolated struct DualCameraDiagnosticsSnapshot: Sendable {
    let state: DualCameraSessionState
    let health: DualCameraHealth
    let generation: Int
    let isCameraScreenActive: Bool
    let isRunning: Bool
    let frontReady: Bool
    let backReady: Bool
    let hardwareCost: Double
    let systemPressureCost: Double
    let recoveryAttempts: Int
    let inputCount: Int
    let outputCount: Int
    let connectionCount: Int
    let thermalState: String
    let systemPressureState: String
}

nonisolated struct DualCameraCaptureResult: @unchecked Sendable {
    let frontImage: UIImage
    let backImage: UIImage
}

@MainActor
final class CameraSessionManager: ObservableObject {
    @Published private(set) var permissionStatus: AVAuthorizationStatus
    @Published private(set) var isSessionRunning = false
    @Published private(set) var currentPosition: AVCaptureDevice.Position = .back
    @Published private(set) var isConfigured = false
    @Published private(set) var isSwitching = false
    @Published private(set) var isCapturing = false
    @Published var capturedImage: UIImage?
    @Published var errorMessage: String?
    @Published var isFlashEnabled = false
    @Published private(set) var sessionMode: CameraSessionMode = .single
    @Published private(set) var dualSessionState: DualCameraSessionState = .idle
    @Published private(set) var dualCameraHealth: DualCameraHealth = .unknown
    @Published private(set) var dualCapturedImages: DualCameraCaptureResult?
    @Published private(set) var lightLevel: Double = 50

    let session: AVCaptureSession
    let dualSession: AVCaptureMultiCamSession
    private let controller: CameraSessionController
    private let dualController: DualCameraSessionController
    private var isApplicationActive = true
    private var isCameraScreenActive = false
    private var dualOperationGeneration = 0
    private var diagnosticSessionID = UUID()

    var supportsDualCamera: Bool { AVCaptureMultiCamSession.isMultiCamSupported }

    /// Single capture authority exposed to UI. Views must not duplicate these conditions.
    var canCapture: Bool {
        guard isApplicationActive, isCameraScreenActive, !isCapturing else { return false }
        if sessionMode == .dual {
            return dualSessionState == .running
                && dualCameraHealth == .healthy
                && dualCapturedImages == nil
        }
        return isConfigured && isSessionRunning
    }

    var dualCameraUXState: DualCameraUXState {
        if permissionStatus == .denied || permissionStatus == .restricted { return .permissionDenied }
        if dualSessionState == .unsupported { return .unsupported }
        if isCapturing { return .capturing }
        if dualSessionState == .interrupted { return .interrupted }
        if dualCameraHealth == .recovering { return .recovering }
        // A transient `.failed` session state remains visually preparing while the controller's
        // bounded automatic recovery owns the failure. User Retry appears only after exhaustion.
        if dualCameraHealth == .unavailable { return .failed }
        return canCapture ? .ready : .preparing
    }

    func markDualPreviewVisible() {
        dualCameraLog("PREVIEW_VISIBLE health=\(dualCameraHealth)")
    }

    func setLightLevel(_ level: Double, isFinal: Bool = false) {
        let clamped = level.isFinite ? min(100, max(0, level)) : 50
        lightLevel = clamped
        guard sessionMode == .dual,
              isApplicationActive,
              isCameraScreenActive,
              !isCapturing else { return }
        dualController.setLightLevel(clamped, generation: dualOperationGeneration, force: isFinal)
    }

    init() {
        #if DEBUG
        DualCameraStateTransitionPolicy.assertRegressionGuards()
        LockULightExposureMapping.assertRegressionGuards()
        #endif
        permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let controller = CameraSessionController()
        let dualController = DualCameraSessionController()
        self.controller = controller
        self.dualController = dualController
        session = controller.session
        dualSession = dualController.session
        dualController.setStateHandler { [weak self] state in
            self?.dualSessionState = state
            if state == .interrupted || state == .stopped || state == .failed {
                self?.isSessionRunning = false
            }
        }
        dualController.setHealthHandler { [weak self] health in
            self?.dualCameraHealth = health
            if self?.sessionMode == .dual {
                self?.isSessionRunning = health == .healthy
            }
        }
    }

    deinit {
        #if DEBUG
        print("[DualCamera][\(diagnosticSessionID.uuidString.prefix(4))][DEINIT]")
        #endif
    }

    func prepare() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionStatus = .authorized
            configureAndStart()
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                permissionStatus = granted ? .authorized : .denied
                if granted { configureAndStart() }
            }
        case .denied:
            permissionStatus = .denied
        case .restricted:
            permissionStatus = .restricted
        @unknown default:
            permissionStatus = .denied
        }
    }

    func startSession() {
        guard permissionStatus == .authorized else { return }
        if sessionMode == .dual {
            dualController.start { [weak self] running in
                self?.dualSessionState = running ? .running : .failed
            }
            return
        }
        if !isConfigured {
            configureAndStart()
            return
        }
        controller.start { [weak self] running in
            self?.isSessionRunning = running
        }
    }

    func stopSession() {
        controller.stop { [weak self] in
            self?.isSessionRunning = false
        }
        dualController.stop { [weak self] in
            self?.dualSessionState = .stopped
        }
    }

    func switchCamera() {
        guard !isSwitching, !isCapturing else { return }
        isSwitching = true
        let desired: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        controller.switchCamera(to: desired) { [weak self] result in
            guard let self else { return }
            self.isSwitching = false
            switch result {
            case .success:
                self.currentPosition = desired
                if desired == .front { self.isFlashEnabled = false }
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func capturePhoto() {
        guard canCapture, sessionMode == .single else { return }
        isCapturing = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        controller.capturePhoto(
            flashEnabled: isFlashEnabled && currentPosition == .back
        ) { [weak self] result in
            guard let self else { return }
            self.isCapturing = false
            switch result {
            case .success(let image):
                self.capturedImage = image.lockUNormalized().lockUDownsampled(maxDimension: 2400)
                self.stopSession()
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func prepareDualCamera(completion: (@MainActor (Bool) -> Void)? = nil) {
        startDualSession(completion: completion)
    }

    func startDualSession(completion: (@MainActor (Bool) -> Void)? = nil) {
        dualCameraLog("OPEN_REQUEST")
        switch dualSessionState {
        case .running:
            dualCameraLog("OPEN_IGNORED_ALREADY_ACTIVE state=running")
            completion?(true)
            return
        case .requestingPermission, .configuring, .ready, .starting:
            dualCameraLog("OPEN_IGNORED_ALREADY_ACTIVE state=\(dualSessionState)")
            return
        default:
            break
        }

        dualCameraLog("OPEN_ACCEPTED")
        let authorization = AVCaptureDevice.authorizationStatus(for: .video)
        dualCameraLog("PERMISSION_CHECK status=\(authorization.rawValue)")
        permissionStatus = authorization
        switch authorization {
        case .authorized:
            startAuthorizedDualSession(completion: completion)
        case .notDetermined:
            let generation = dualOperationGeneration
            dualSessionState = .requestingPermission
            dualCameraLog("requesting permission")
            Task { @MainActor [weak self] in
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                guard let self, generation == self.dualOperationGeneration else { return }
                self.permissionStatus = granted ? .authorized : .denied
                if granted {
                    self.dualCameraLog("permission authorized")
                    self.startAuthorizedDualSession(completion: completion)
                } else {
                    self.dualSessionState = .failed
                    self.errorMessage = LockUCameraError.cameraPermissionDenied.localizedDescription
                    completion?(false)
                }
            }
        case .denied, .restricted:
            dualSessionState = .failed
            errorMessage = LockUCameraError.cameraPermissionDenied.localizedDescription
            completion?(false)
        @unknown default:
            dualSessionState = .failed
            errorMessage = LockUCameraError.cameraPermissionDenied.localizedDescription
            completion?(false)
        }
    }

    private func startAuthorizedDualSession(completion: (@MainActor (Bool) -> Void)?) {
        guard isApplicationActive, isCameraScreenActive else {
            completion?(false)
            return
        }
        guard supportsDualCamera else {
            dualSessionState = .unsupported
            errorMessage = "Dual Cameraはこの端末では利用できません。通常のカメラに切り替えました。"
            sessionMode = .single
            startSession()
            completion?(false)
            return
        }
        let generation = dualOperationGeneration
        controller.stop { [weak self] in
            guard let self else { return }
            guard generation == self.dualOperationGeneration, self.isApplicationActive, self.isCameraScreenActive else {
                completion?(false)
                return
            }
            self.isSessionRunning = false
            self.dualSessionState = .configuring
            self.dualCameraLog("configuring")
            self.dualController.configure { [weak self] result in
                guard let self else { return }
                guard generation == self.dualOperationGeneration, self.isApplicationActive, self.isCameraScreenActive else {
                    self.dualController.stop { }
                    completion?(false)
                    return
                }
                switch result {
                case .success:
                    self.sessionMode = .dual
                    self.dualSessionState = .ready
                    self.dualController.start { [weak self] running in
                        guard let self else { return }
                        guard generation == self.dualOperationGeneration,
                              self.isApplicationActive,
                              self.isCameraScreenActive else {
                            self.dualController.stop { }
                            completion?(false)
                            return
                        }
                        self.dualSessionState = running ? .running : .failed
                        completion?(running)
                    }
                case .failure:
                    self.dualSessionState = .failed
                    self.sessionMode = .single
                    self.errorMessage = "Dual Cameraを開始できませんでした。通常のカメラで撮影できます。"
                    self.configureAndStart()
                    completion?(false)
                }
            }
        }
    }

    func stopDualSession() {
        dualOperationGeneration &+= 1
        dualSessionState = .stopping
        dualController.stop { [weak self] in
            guard let self else { return }
            self.isSessionRunning = false
            self.isCapturing = false
            self.dualSessionState = .stopped
        }
    }

    func useSingleCamera() {
        dualOperationGeneration &+= 1
        dualSessionState = .stopping
        dualController.stop { [weak self] in
            guard let self else { return }
            self.sessionMode = .single
            self.dualSessionState = .stopped
            self.startSession()
        }
    }

    func captureDualPhoto() {
        guard canCapture, sessionMode == .dual else {
            dualCameraLog("WARNING capture rejected state=\(dualSessionState) health=\(dualCameraHealth)")
            return
        }
        isCapturing = true
        dualCapturedImages = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dualController.capture { [weak self] result in
            guard let self else { return }
            self.isCapturing = false
            switch result {
            case .success(let capture):
                self.dualCapturedImages = capture
                self.stopDualSession()
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func clearDualCapture() {
        dualCapturedImages = nil
    }

    func retakeDualCapture() {
        guard sessionMode == .dual else { return }
        dualCapturedImages = nil
        startDualSession()
    }

    func retryDualCamera() {
        guard isApplicationActive, isCameraScreenActive, dualCameraHealth == .unavailable else { return }
        dualCameraHealth = .recovering
        dualController.retry()
    }

    @discardableResult
    func connectDualPreview(
        backLayer: AVCaptureVideoPreviewLayer,
        frontLayer: AVCaptureVideoPreviewLayer,
        previewID: String
    ) -> UUID {
        let attachmentID = UUID()
        dualController.connectPreview(
            backLayer: backLayer,
            frontLayer: frontLayer,
            attachmentID: attachmentID,
            previewID: previewID,
            generation: dualOperationGeneration
        )
        return attachmentID
    }

    func disconnectDualPreview(
        backLayer: AVCaptureVideoPreviewLayer,
        frontLayer: AVCaptureVideoPreviewLayer,
        attachmentID: UUID,
        previewID: String
    ) {
        dualController.disconnectPreview(
            backLayer: backLayer,
            frontLayer: frontLayer,
            attachmentID: attachmentID,
            previewID: previewID,
            generation: dualOperationGeneration
        )
    }

    func setApplicationActive(_ isActive: Bool) {
        isApplicationActive = isActive
        permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if !isActive {
            dualOperationGeneration &+= 1
        }
        dualController.updateDiagnosticContext(generation: dualOperationGeneration, screenActive: isCameraScreenActive && isApplicationActive)
    }

    func setCameraScreenActive(_ isActive: Bool) {
        if isActive, !isCameraScreenActive {
            diagnosticSessionID = UUID()
            lightLevel = 50
            dualCameraLog("OPEN")
        } else if !isActive, isCameraScreenActive {
            dualCameraLog("CLOSE")
        }
        isCameraScreenActive = isActive
        if !isActive {
            dualOperationGeneration &+= 1
        }
        dualController.updateDiagnosticContext(generation: dualOperationGeneration, screenActive: isCameraScreenActive && isApplicationActive)
        dualController.updateDiagnosticSession(id: diagnosticSessionID, isOpen: isActive)
        if isActive { dualController.setLightLevel(50, generation: dualOperationGeneration, force: true) }
    }

    func retake() {
        capturedImage = nil
        startSession()
    }

    private func configureAndStart() {
        guard !isConfigured else {
            startSession()
            return
        }
        controller.configure(position: currentPosition) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.isConfigured = true
                self.startSession()
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func dualCameraLog(_ message: String) {
        #if DEBUG
        print("[DualCamera][\(diagnosticSessionID.uuidString.prefix(4))] \(message)")
        #endif
    }
}

private nonisolated final class DualCameraSessionController: NSObject, @unchecked Sendable {
    enum CameraSide: Hashable { case front, back }
    enum ConfigurationTier: String { case systemBalanced }

    let session = AVCaptureMultiCamSession()
    private let sessionQueue = DispatchQueue(label: "com.locku.camera.dual.session", qos: .userInitiated)
    private let processingQueue = DispatchQueue(label: "com.locku.camera.dual.processing", qos: .userInitiated)
    private let frontOutput = AVCapturePhotoOutput()
    private let backOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var isConfiguring = false
    private var isStarting = false
    private var activeCaptureID: UUID?
    private var pendingImages: [CameraSide: UIImage] = [:]
    private var delegates: [CameraSide: DualPhotoDelegate] = [:]
    private var captureCompletion: (@MainActor (Result<DualCameraCaptureResult, Error>) -> Void)?
    private var timeoutWorkItem: DispatchWorkItem?
    private var previewConnections: [AVCaptureConnection] = []
    private var pendingPreviewLayers: DualPreviewLayers?
    private var activePreviewAttachmentID: UUID?
    private weak var connectedBackLayer: AVCaptureVideoPreviewLayer?
    private weak var connectedFrontLayer: AVCaptureVideoPreviewLayer?
    private var wantsToRun = false
    private var stateHandler: (@MainActor (DualCameraSessionState) -> Void)?
    private var state: DualCameraSessionState = .idle
    private var healthHandler: (@MainActor (DualCameraHealth) -> Void)?
    private var health: DualCameraHealth = .unknown
    private var recoveryAttempt = 0
    private let maximumRecoveryAttempts = 2
    private var isRecovering = false
    private var healthValidationWorkItem: DispatchWorkItem?
    private var pendingStartCompletion: (@MainActor (Bool) -> Void)?
    private var configurationStartedAt: UInt64?
    private var sessionStartRequestedAt: UInt64?
    private var lifecycleGeneration = 0
    private var cameraScreenActive = false
    private var diagnosticSessionID = "----"
    private var configurationTier: ConfigurationTier = .systemBalanced
    private var desiredLightLevel: Double = 50
    private var lastExposureUpdateNanos: UInt64 = 0
    private let minimumExposureUpdateIntervalNanos: UInt64 = 33_000_000

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted(_:)),
            name: AVCaptureSession.wasInterruptedNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: AVCaptureSession.interruptionEndedNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError(_:)),
            name: AVCaptureSession.runtimeErrorNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionDidStartRunning),
            name: AVCaptureSession.didStartRunningNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionDidStopRunning),
            name: AVCaptureSession.didStopRunningNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: ProcessInfo.processInfo
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        #if DEBUG
        print("[DualCamera][\(diagnosticSessionID)][DEINIT] controller")
        #endif
    }

    func setStateHandler(_ handler: @escaping @MainActor (DualCameraSessionState) -> Void) {
        stateHandler = handler
    }

    func setHealthHandler(_ handler: @escaping @MainActor (DualCameraHealth) -> Void) {
        healthHandler = handler
    }

    func retry() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsToRun = true
            self.recoveryAttempt = max(0, self.maximumRecoveryAttempts - 1)
            self.performRecovery(reason: "user retry")
        }
    }

    func updateDiagnosticContext(generation: Int, screenActive: Bool) {
        sessionQueue.async { [weak self] in
            self?.lifecycleGeneration = generation
            self?.cameraScreenActive = screenActive
        }
    }

    func updateDiagnosticSession(id: UUID, isOpen: Bool) {
        let shortID = String(id.uuidString.prefix(4))
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.diagnosticSessionID = shortID
            self.diagnosticPrint(isOpen ? "OPEN" : "CLOSE", "screenActive=\(isOpen)")
        }
    }

    func setLightLevel(_ level: Double, generation: Int, force: Bool) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.desiredLightLevel = level.isFinite ? min(100, max(0, level)) : 50
            guard generation == self.lifecycleGeneration,
                  self.cameraScreenActive,
                  self.health == .healthy,
                  self.activeCaptureID == nil else { return }
            self.applyDesiredLightLevel(force: force)
        }
    }

    func configure(completion: @escaping @MainActor (Result<Void, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.isConfigured {
                Task { @MainActor in completion(.success(())) }
                return
            }
            guard !self.isConfiguring else { return }
            self.isConfiguring = true
            self.configurationStartedAt = DispatchTime.now().uptimeNanoseconds
            self.publishState(.configuring)
            defer { self.isConfiguring = false }
            do {
                try self.configureSession()
                self.isConfigured = true
                self.connectPendingPreviewIfPossible()
                self.logCosts()
                self.logConfigurationFingerprint()
                self.publishState(.ready)
                Task { @MainActor in completion(.success(())) }
            } catch {
                self.resetConfiguration()
                self.publishState(.failed)
                self.dumpFailureContext(reason: error.localizedDescription)
                Task { @MainActor in completion(.failure(error)) }
            }
        }
    }

    func start(completion: @escaping @MainActor (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsToRun = true
            guard !self.session.isRunning else {
                Task { @MainActor in completion(true) }
                return
            }
            guard !self.isStarting else {
                self.debugLog("duplicate start ignored")
                return
            }
            self.pendingStartCompletion = completion
            guard self.isConfigured else {
                self.debugLog("START_WAITING_FOR_CONFIGURATION")
                return
            }
            guard self.previewConnections.count == 2 else {
                self.debugLog("START_WAITING_FOR_PREVIEW")
                return
            }
            self.startWhenReady()
        }
    }

    private func startWhenReady() {
        guard wantsToRun, cameraScreenActive, isConfigured,
              previewConnections.count == 2, !session.isRunning, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        publishState(.starting)
        publishHealth(.starting)
        sessionStartRequestedAt = DispatchTime.now().uptimeNanoseconds
        debugLog("START_REQUEST")
        dumpSessionState(prefix: "before startRunning")
        session.startRunning()
        let running = session.isRunning
        publishState(running ? .running : .failed)
        if running {
            validateHealthOrScheduleTimeout()
            let pending = pendingStartCompletion
            pendingStartCompletion = nil
            Task { @MainActor in pending?(true) }
        } else {
            publishHealth(.degraded)
            performRecovery(reason: "startRunning returned false")
        }
        debugLog(running ? "session started" : "session failed to start", isError: !running)
    }

    func stop(completion: @escaping @MainActor () -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsToRun = false
            self.isStarting = false
            self.cancelHealthValidation()
            let pendingStart = self.pendingStartCompletion
            self.pendingStartCompletion = nil
            self.publishState(.stopping)
            self.debugLog("STOP_REQUEST")
            self.cancelCapture(with: LockUCameraError.dualCaptureFailed, notify: false)
            if self.session.isRunning { self.session.stopRunning() }
            self.publishState(.stopped)
            self.publishHealth(.unknown)
            self.debugLog("SESSION_STOPPED")
            Task { @MainActor in
                pendingStart?(false)
                completion()
            }
        }
    }

    @objc private func sessionWasInterrupted(_ notification: Notification) {
        let reason = (notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? NSNumber)?.intValue
        sessionQueue.async { [weak self] in
            guard let self, self.wantsToRun, self.cameraScreenActive else { return }
            self.debugLog("INTERRUPTED reason=\(reason.map(String.init) ?? "unknown")")
            self.cancelCapture(with: LockUCameraError.dualCaptureFailed, notify: false)
            self.cancelHealthValidation()
            self.publishState(.interrupted)
            self.publishHealth(.degraded)
        }
    }

    @objc private func sessionInterruptionEnded() {
        sessionQueue.async { [weak self] in
            guard let self,
                  self.wantsToRun,
                  self.cameraScreenActive,
                  self.isConfigured,
                  !self.session.isRunning else { return }
            self.debugLog("INTERRUPTION_ENDED")
            self.publishState(.starting)
            self.session.startRunning()
            self.publishState(self.session.isRunning ? .running : .failed)
            if self.session.isRunning { self.validateHealthOrScheduleTimeout() }
        }
    }

    @objc private func sessionRuntimeError(_ notification: Notification) {
        let rawError = notification.userInfo?[AVCaptureSessionErrorKey]
        let snapshot = DualRuntimeErrorSnapshot(
            error: rawError as? NSError,
            notificationUserInfo: notification.userInfo
        )
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.debugRuntimeError(snapshot)
            guard snapshot.isMediaServicesReset else {
                self.publishState(.failed)
                self.publishHealth(.unavailable)
                return
            }
            guard self.wantsToRun, self.cameraScreenActive else { return }
            // Media-services reset invalidates the old input/connection graph.
            self.resetConfiguration(preservingPendingPreview: true)
            self.performRecovery(reason: "mediaServicesWereReset")
        }
    }

    @objc private func thermalStateDidChange() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let thermal = ProcessInfo.processInfo.thermalState
            let details = "thermal=\(thermal) lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled)"
            if thermal == .serious || thermal == .critical {
                self.diagnosticPrint("WARNING", details + "; retaining stable configuration")
            } else {
                self.debugLog(details)
            }
        }
    }

    @objc private func sessionDidStartRunning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.wantsToRun, self.cameraScreenActive, self.session.isRunning else {
                self.debugLog("stale SESSION_RUNNING ignored")
                return
            }
            self.debugLog("SESSION_RUNNING")
            self.publishState(.running)
            self.validateHealthOrScheduleTimeout()
        }
    }

    @objc private func sessionDidStopRunning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.debugLog("didStopRunning")
            if !self.wantsToRun { self.publishState(.stopped) }
        }
    }

    private func publishState(_ state: DualCameraSessionState) {
        let previous = self.state
        guard DualCameraStateTransitionPolicy.permits(from: previous, to: state) else {
            diagnosticPrint("ERROR", "forbidden transition \(previous) -> \(state)")
            #if DEBUG
            assertionFailure("Forbidden Dual Camera transition: \(previous) -> \(state)")
            #endif
            self.state = .failed
            let handler = stateHandler
            Task { @MainActor in handler?(.failed) }
            return
        }
        self.state = state
        #if DEBUG
        if previous != state { diagnosticPrint("STATE", "\(previous) -> \(state)") }
        #endif
        let handler = stateHandler
        Task { @MainActor in handler?(state) }
    }

    private func publishHealth(_ health: DualCameraHealth) {
        let previous = self.health
        self.health = health
        #if DEBUG
        if previous != health { diagnosticPrint("HEALTH", "\(previous) -> \(health)") }
        #endif
        validateInvariants(for: health)
        let handler = healthHandler
        Task { @MainActor in handler?(health) }
    }

    private func validateInvariants(for health: DualCameraHealth) {
        #if DEBUG
        if health == .healthy {
            assert(session.isRunning, "Healthy Dual Camera must have a running session")
            assert(cameraScreenActive, "Healthy Dual Camera must have an active camera screen")
        }
        if health == .recovering {
            assert(recoveryAttempt > 0, "Recovering Dual Camera must have a recovery attempt")
        }
        if activeCaptureID != nil {
            assert(cameraScreenActive, "Active capture cannot outlive its camera screen")
        }
        #endif
    }

    private var frontPreviewReady: Bool { previewConnectionReady(for: .front) }
    private var backPreviewReady: Bool { previewConnectionReady(for: .back) }
    private var frontCaptureReady: Bool { outputConnectionReady(frontOutput.connection(with: .video)) }
    private var backCaptureReady: Bool { outputConnectionReady(backOutput.connection(with: .video)) }

    private var isDualCameraUsable: Bool {
        session.isRunning && frontPreviewReady && backPreviewReady && frontCaptureReady && backCaptureReady
    }

    private func previewConnectionReady(for position: AVCaptureDevice.Position) -> Bool {
        previewConnections.contains { connection in
            connection.isEnabled
                && connection.isActive
                && connection.inputPorts.contains(where: { $0.sourceDevicePosition == position })
        }
    }

    private func outputConnectionReady(_ connection: AVCaptureConnection?) -> Bool {
        guard let connection else { return false }
        return connection.isEnabled && connection.isActive
    }

    private func applyDesiredLightLevel(force: Bool) {
        let now = DispatchTime.now().uptimeNanoseconds
        guard force || now &- lastExposureUpdateNanos >= minimumExposureUpdateIntervalNanos else { return }
        lastExposureUpdateNanos = now

        let inputs = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
        for position in [AVCaptureDevice.Position.front, .back] {
            guard let device = inputs.first(where: { $0.device.position == position })?.device else {
                debugLog("Light WARNING missing \(position == .front ? "front" : "back") device", isError: true)
                continue
            }
            applyLightLevel(desiredLightLevel, to: device, position: position, shouldLog: force)
        }
    }

    private func applyLightLevel(
        _ level: Double,
        to device: AVCaptureDevice,
        position: AVCaptureDevice.Position,
        shouldLog: Bool
    ) {
        let role: LightExposureCameraRole = position == .front ? .front : .back
        let bias = LockULightExposureMapping.bias(
            lightLevel: level,
            deviceMinimum: device.minExposureTargetBias,
            deviceMaximum: device.maxExposureTargetBias,
            role: role
        )
        guard device.minExposureTargetBias < 0 || device.maxExposureTargetBias > 0 else {
            debugLog("Light WARNING exposure bias unavailable for \(position == .front ? "front" : "back")")
            return
        }
        let sideName = position == .front ? "front" : "back"
        let safeLevel = level.isFinite ? min(100, max(0, level)) : 50
        let percentageValue = Int(safeLevel.rounded())

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.setExposureTargetBias(bias) { _ in
                #if DEBUG
                if shouldLog {
                    print(
                        "[DualCamera][Light] position=\(sideName) " +
                        "level=\(percentageValue) bias=\(bias)"
                    )
                }
                #endif
            }
        } catch {
            debugLog(
                "Light WARNING \(position == .front ? "front" : "back") exposure update failed: \(error.localizedDescription)",
                isError: true
            )
        }
    }

    private func validateHealthOrScheduleTimeout() {
        guard wantsToRun else { return }
        if isDualCameraUsable {
            cancelHealthValidation()
            recoveryAttempt = 0
            publishHealth(.healthy)
            applyDesiredLightLevel(force: true)
            debugLog("CAMERA_HEALTHY")
            logStartupMetrics()
            logDiagnostics(reason: "healthy")
            return
        }

        publishHealth(.starting)
        guard healthValidationWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.healthValidationWorkItem = nil
            guard self.wantsToRun else { return }
            if self.isDualCameraUsable {
                self.recoveryAttempt = 0
                self.publishHealth(.healthy)
                self.applyDesiredLightLevel(force: true)
                self.debugLog("CAMERA_HEALTHY")
                self.logStartupMetrics()
            } else {
                self.publishHealth(.degraded)
                self.logDiagnostics(reason: "startup health timeout")
                self.performRecovery(reason: "startup health timeout")
            }
        }
        healthValidationWorkItem = workItem
        sessionQueue.asyncAfter(deadline: .now() + 2.5, execute: workItem)
    }

    private func cancelHealthValidation() {
        healthValidationWorkItem?.cancel()
        healthValidationWorkItem = nil
    }

    private func performRecovery(reason: String) {
        guard wantsToRun, cameraScreenActive, !isRecovering else { return }
        guard recoveryAttempt < maximumRecoveryAttempts else {
            cancelHealthValidation()
            publishState(.failed)
            publishHealth(.unavailable)
            dumpFailureContext(reason: "\(reason); recovery limit reached")
            let pending = pendingStartCompletion
            pendingStartCompletion = nil
            Task { @MainActor in pending?(false) }
            return
        }

        isRecovering = true
        recoveryAttempt += 1
        publishHealth(.recovering)
        cancelHealthValidation()
        defer { isRecovering = false }

        if session.isRunning { session.stopRunning() }
        do {
            if recoveryAttempt == 2 || !hasValidConfiguration || previewConnections.count != 2 {
                let previewLayers = connectedBackLayer.flatMap { back in
                    connectedFrontLayer.map { front in
                        DualPreviewLayers(
                            back: back,
                            front: front,
                            attachmentID: activePreviewAttachmentID ?? UUID(),
                            previewID: "preserved",
                            generation: lifecycleGeneration
                        )
                    }
                } ?? pendingPreviewLayers
                resetConfiguration()
                pendingPreviewLayers = previewLayers
                try configureSession()
                isConfigured = true
                connectPendingPreviewIfPossible()
                logConfigurationFingerprint()
            }
            guard hasValidConfiguration, previewConnections.count == 2 else {
                throw LockUCameraError.dualCaptureFailed
            }
            publishState(.starting)
            session.startRunning()
            publishState(session.isRunning ? .running : .failed)
            if session.isRunning {
                let pending = pendingStartCompletion
                pendingStartCompletion = nil
                Task { @MainActor in pending?(true) }
                validateHealthOrScheduleTimeout()
            }
            else { publishHealth(.degraded) }
        } catch {
            isConfigured = false
            publishState(.failed)
            publishHealth(recoveryAttempt >= maximumRecoveryAttempts ? .unavailable : .degraded)
            dumpFailureContext(reason: "\(reason); \(error.localizedDescription)")
            if recoveryAttempt < maximumRecoveryAttempts {
                sessionQueue.async { [weak self] in
                    self?.performRecovery(reason: "recovery retry after failure")
                }
            } else {
                let pending = pendingStartCompletion
                pendingStartCompletion = nil
                Task { @MainActor in pending?(false) }
            }
        }
    }

    private var hasValidConfiguration: Bool {
        let inputs = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
        return inputs.contains(where: { $0.device.position == .front })
            && inputs.contains(where: { $0.device.position == .back })
            && session.outputs.contains(where: { $0 === frontOutput })
            && session.outputs.contains(where: { $0 === backOutput })
    }

    func capture(completion: @escaping @MainActor (Result<DualCameraCaptureResult, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isConfigured, self.health == .healthy, self.activeCaptureID == nil else {
                #if DEBUG
                print("[DualCamera][FATAL_STATE] capture requested while health=\(self.health)")
                #endif
                Task { @MainActor in completion(.failure(LockUCameraError.dualCaptureFailed)) }
                return
            }
            let captureID = UUID()
            self.activeCaptureID = captureID
            self.debugLog("CAPTURE_REQUEST id=\(captureID.uuidString.prefix(4))")
            self.pendingImages = [:]
            self.captureCompletion = completion

            let frontDelegate = DualPhotoDelegate(captureID: captureID, side: .front) { [weak self] id, side, result in
                self?.receive(captureID: id, side: side, result: result)
            }
            let backDelegate = DualPhotoDelegate(captureID: captureID, side: .back) { [weak self] id, side, result in
                self?.receive(captureID: id, side: side, result: result)
            }
            self.delegates = [.front: frontDelegate, .back: backDelegate]
            self.prepareConnection(self.frontOutput.connection(with: .video))
            self.prepareConnection(self.backOutput.connection(with: .video))
            self.frontOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: frontDelegate)
            self.backOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: backDelegate)

            let timeout = DispatchWorkItem { [weak self] in
                guard self?.activeCaptureID == captureID else { return }
                self?.cancelCapture(with: LockUCameraError.dualCaptureFailed, notify: true)
            }
            self.timeoutWorkItem = timeout
            self.sessionQueue.asyncAfter(deadline: .now() + 6, execute: timeout)
        }
    }

    func connectPreview(
        backLayer: AVCaptureVideoPreviewLayer,
        frontLayer: AVCaptureVideoPreviewLayer,
        attachmentID: UUID,
        previewID: String,
        generation: Int
    ) {
        let layers = DualPreviewLayers(
            back: backLayer,
            front: frontLayer,
            attachmentID: attachmentID,
            previewID: previewID,
            generation: generation
        )
        sessionQueue.async { [weak self, layers] in
            guard let self else { return }
            guard generation == self.lifecycleGeneration, self.cameraScreenActive else {
                self.debugLog("PREVIEW_ATTACH_IGNORED_STALE preview=\(previewID) generation=\(generation)")
                return
            }
            self.debugLog("PREVIEW_ATTACH preview=\(previewID) generation=\(generation)")
            if let activeID = self.activePreviewAttachmentID, activeID != attachmentID {
                self.removeCurrentPreviewConnections()
            }
            self.pendingPreviewLayers = layers
            self.connectPendingPreviewIfPossible()
        }
    }

    private func connectPendingPreviewIfPossible() {
        guard isConfigured,
              previewConnections.isEmpty,
              let layers = pendingPreviewLayers else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard let frontInput = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first(where: { $0.device.position == .front }),
              let backInput = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first(where: { $0.device.position == .back }) else { return }
        guard let front = makePreviewConnection(input: frontInput, layer: layers.front, mirrored: true) else { return }
        guard let back = makePreviewConnection(input: backInput, layer: layers.back, mirrored: false) else {
            if session.connections.contains(where: { $0 === front }) {
                session.removeConnection(front)
            }
            return
        }
        previewConnections = [front, back]
        connectedBackLayer = layers.back
        connectedFrontLayer = layers.front
        activePreviewAttachmentID = layers.attachmentID
        pendingPreviewLayers = nil
        debugLog("CONNECTIONS_READY preview=\(layers.previewID) generation=\(layers.generation)")
        sessionQueue.async { [weak self] in self?.startWhenReady() }
    }

    func disconnectPreview(
        backLayer: AVCaptureVideoPreviewLayer,
        frontLayer: AVCaptureVideoPreviewLayer,
        attachmentID: UUID,
        previewID: String,
        generation: Int
    ) {
        let layers = DualPreviewLayers(
            back: backLayer,
            front: frontLayer,
            attachmentID: attachmentID,
            previewID: previewID,
            generation: generation
        )
        sessionQueue.async { [weak self, layers] in
            guard let self else { return }
            guard generation == self.lifecycleGeneration,
                  self.activePreviewAttachmentID == attachmentID || self.pendingPreviewLayers?.attachmentID == attachmentID else {
                self.debugLog("PREVIEW_DETACH_IGNORED_STALE preview=\(previewID) generation=\(generation)")
                return
            }
            self.debugLog("PREVIEW_DETACH preview=\(previewID) generation=\(generation)")
            if self.pendingPreviewLayers?.attachmentID == attachmentID {
                self.pendingPreviewLayers = nil
            }
            guard self.activePreviewAttachmentID == attachmentID,
                  self.connectedBackLayer === layers.back,
                  self.connectedFrontLayer === layers.front else { return }

            self.removeCurrentPreviewConnections()
        }
    }

    private func removeCurrentPreviewConnections() {
        session.beginConfiguration()
        for connection in previewConnections where session.connections.contains(where: { $0 === connection }) {
            session.removeConnection(connection)
        }
        previewConnections = []
        connectedBackLayer = nil
        connectedFrontLayer = nil
        activePreviewAttachmentID = nil
        session.commitConfiguration()
    }

    private func configureSession() throws {
        debugLog("isMultiCamSupported: \(AVCaptureMultiCamSession.isMultiCamSupported)")
        guard AVCaptureMultiCamSession.isMultiCamSupported else { throw LockUCameraError.cameraUnavailable }
        debugLog("CONFIG_BEGIN")
        debugLog(
            "CONFIG tier=\(configurationTier.rawValue) lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled)"
        )
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
            debugLog("CONFIG_COMMIT")
        }

        let frontInput = try makeInput(position: .front)
        let backInput = try makeInput(position: .back)
        guard session.canAddInput(frontInput) else {
            debugLog("cannot add front input", isError: true)
            throw LockUCameraError.cannotAddInput
        }
        guard session.canAddInput(backInput) else {
            debugLog("cannot add back input", isError: true)
            throw LockUCameraError.cannotAddInput
        }
        session.addInputWithNoConnections(frontInput)
        debugLog("INPUT_FRONT_ADDED")
        session.addInputWithNoConnections(backInput)
        debugLog("INPUT_BACK_ADDED")
        guard session.canAddOutput(frontOutput) else {
            debugLog("cannot add front photo output", isError: true)
            throw LockUCameraError.cannotAddOutput
        }
        guard session.canAddOutput(backOutput) else {
            debugLog("cannot add back photo output", isError: true)
            throw LockUCameraError.cannotAddOutput
        }
        session.addOutputWithNoConnections(frontOutput)
        debugLog("OUTPUT_FRONT_ADDED")
        session.addOutputWithNoConnections(backOutput)
        debugLog("OUTPUT_BACK_ADDED")

        try connect(input: frontInput, output: frontOutput, position: .front)
        try connect(input: backInput, output: backOutput, position: .back)
        frontOutput.maxPhotoQualityPrioritization = .balanced
        backOutput.maxPhotoQualityPrioritization = .balanced
    }

    private func connect(input: AVCaptureDeviceInput, output: AVCapturePhotoOutput, position: AVCaptureDevice.Position) throws {
        guard let port = input.ports.first(where: { $0.mediaType == .video && $0.sourceDevicePosition == position }) else {
            throw LockUCameraError.cannotAddInput
        }
        let connection = AVCaptureConnection(inputPorts: [port], output: output)
        guard session.canAddConnection(connection) else {
            debugLog("cannot add \(position == .front ? "front" : "back") photo output connection", isError: true)
            throw LockUCameraError.cannotAddOutput
        }
        session.addConnection(connection)
        debugLog(position == .front ? "[CONFIG] front input connected" : "[CONFIG] back input connected")
    }

    private func makeInput(position: AVCaptureDevice.Position) throws -> AVCaptureDeviceInput {
        guard let device = discoverDevice(position: position) else {
            throw LockUCameraError.cameraUnavailable
        }
        debugLog(
            "CONFIG device position=\(position == .front ? "front" : "back") " +
            "type=\(device.deviceType.rawValue)"
        )
        do { return try AVCaptureDeviceInput(device: device) }
        catch { throw LockUCameraError.inputCreationFailed }
    }

    private func discoverDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let preferred = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
        if let preferred { return preferred }

        let types: [AVCaptureDevice.DeviceType] = position == .front
            ? [.builtInWideAngleCamera, .builtInTrueDepthCamera]
            : [.builtInWideAngleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInTripleCamera]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: position
        )
        let fallbackDevice = discovery.devices.first { $0.position == position }
        debugLog(
            "CONFIG fallback reason=preferred wide unavailable " +
            "position=\(position == .front ? "front" : "back") result=\(fallbackDevice?.deviceType.rawValue ?? "none")"
        )
        return fallbackDevice
    }

    private func prepareConnection(_ connection: AVCaptureConnection?) {
        guard let connection else { return }
        configureVideoConnection(connection, mirrored: false)
    }

    private func makePreviewConnection(
        input: AVCaptureDeviceInput,
        layer: AVCaptureVideoPreviewLayer,
        mirrored: Bool
    ) -> AVCaptureConnection? {
        guard let port = input.ports.first(where: { $0.mediaType == .video && $0.sourceDevicePosition == input.device.position }) else { return nil }
        let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: layer)
        guard session.canAddConnection(connection) else {
            debugLog("cannot add \(mirrored ? "front" : "back") preview connection", isError: true)
            return nil
        }
        configureVideoConnection(connection, mirrored: mirrored)
        session.addConnection(connection)
        return connection
    }

    private func configureVideoConnection(_ connection: AVCaptureConnection, mirrored: Bool) {
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }

    private func receive(captureID: UUID, side: CameraSide, result: Result<UIImage, Error>) {
        sessionQueue.async { [weak self] in
            guard let self, self.activeCaptureID == captureID else { return }
            switch result {
            case .failure:
                self.cancelCapture(with: LockUCameraError.dualCaptureFailed, notify: true)
            case .success(let image):
                self.debugLog(side == .front ? "front captured" : "back captured")
                self.pendingImages[side] = image
                guard let front = self.pendingImages[.front], let back = self.pendingImages[.back] else { return }
                self.timeoutWorkItem?.cancel()
                self.timeoutWorkItem = nil
                self.delegates = [:]
                self.processingQueue.async {
                    let result = DualCameraCaptureResult(
                        frontImage: front.lockUNormalized().lockUDownsampled(maxDimension: 2400),
                        backImage: back.lockUNormalized().lockUDownsampled(maxDimension: 2400)
                    )
                    self.sessionQueue.async {
                        guard self.activeCaptureID == captureID else { return }
                        self.activeCaptureID = nil
                        self.pendingImages = [:]
                        let completion = self.captureCompletion
                        self.captureCompletion = nil
                        self.debugLog("CAPTURE_COMPLETE id=\(captureID.uuidString.prefix(4))")
                        Task { @MainActor in completion?(.success(result)) }
                    }
                }
            }
        }
    }

    private func cancelCapture(with error: Error, notify: Bool) {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        activeCaptureID = nil
        pendingImages = [:]
        delegates = [:]
        let completion = captureCompletion
        captureCompletion = nil
        if notify { Task { @MainActor in completion?(.failure(error)) } }
    }

    private func resetConfiguration(preservingPendingPreview: Bool = false) {
        let preservedPreview = preservingPendingPreview
            ? connectedBackLayer.flatMap { back in
                connectedFrontLayer.map { front in
                    DualPreviewLayers(
                        back: back,
                        front: front,
                        attachmentID: activePreviewAttachmentID ?? UUID(),
                        previewID: "preserved",
                        generation: lifecycleGeneration
                    )
                }
            } ?? pendingPreviewLayers
            : nil
        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        previewConnections = []
        pendingPreviewLayers = preservedPreview
        connectedBackLayer = nil
        connectedFrontLayer = nil
        activePreviewAttachmentID = nil
        session.commitConfiguration()
        isConfigured = false
    }

    private func logCosts() {
        #if DEBUG
        print("[DualCamera][COST] hardwareCost = \(session.hardwareCost)")
        print("[DualCamera][COST] systemPressureCost = \(session.systemPressureCost)")
        #endif
    }

    private func logConfigurationFingerprint() {
        #if DEBUG
        let inputs = session.inputs.compactMap { $0 as? AVCaptureDeviceInput }
        print("[DualCamera][CONFIG] tier=\(configurationTier.rawValue) inputs=\(session.inputs.count) outputs=\(session.outputs.count) connections=\(session.connections.count)")
        for input in inputs {
            let device = input.device
            let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
            let fps = device.activeVideoMinFrameDuration.seconds > 0 ? 1 / device.activeVideoMinFrameDuration.seconds : 0
            print("[DualCamera][CONFIG] \(device.position == .front ? "front" : "back") device=\(device.localizedName) format=\(dimensions.width)x\(dimensions.height) fps=\(String(format: "%.1f", fps))")
        }
        #endif
    }

    private func logStartupMetrics() {
        #if DEBUG
        let now = DispatchTime.now().uptimeNanoseconds
        if let configurationStartedAt {
            print("[DualCamera][METRIC] configurationToHealthy = \(milliseconds(from: configurationStartedAt, to: now))ms")
        }
        if let sessionStartRequestedAt {
            print("[DualCamera][METRIC] sessionStartToHealthy = \(milliseconds(from: sessionStartRequestedAt, to: now))ms")
        }
        #endif
        configurationStartedAt = nil
        sessionStartRequestedAt = nil
    }

    private func milliseconds(from start: UInt64, to end: UInt64) -> Int {
        Int((end &- start) / 1_000_000)
    }

    private func logDiagnostics(reason: String) {
        #if DEBUG
        let snapshot = diagnosticsSnapshot()
        let authorization = AVCaptureDevice.authorizationStatus(for: .video).rawValue
        diagnosticPrint(
            "DIAGNOSTICS",
            "reason=\(reason) health=\(snapshot.health) running=\(snapshot.isRunning) " +
            "screenActive=\(snapshot.isCameraScreenActive) authorization=\(authorization) " +
            "frontReady=\(snapshot.frontReady) backReady=\(snapshot.backReady) " +
            "inputs=\(snapshot.inputCount) outputs=\(snapshot.outputCount) connections=\(snapshot.connectionCount) " +
            "hardwareCost=\(snapshot.hardwareCost) systemPressureCost=\(snapshot.systemPressureCost) " +
            "thermal=\(snapshot.thermalState) pressure=\(snapshot.systemPressureState) " +
            "recovery=\(snapshot.recoveryAttempts)/\(maximumRecoveryAttempts)"
        )
        #endif
    }

    private func diagnosticsSnapshot() -> DualCameraDiagnosticsSnapshot {
        let devices = session.inputs.compactMap { ($0 as? AVCaptureDeviceInput)?.device }
        return DualCameraDiagnosticsSnapshot(
            state: state,
            health: health,
            generation: lifecycleGeneration,
            isCameraScreenActive: cameraScreenActive,
            isRunning: session.isRunning,
            frontReady: frontPreviewReady && frontCaptureReady,
            backReady: backPreviewReady && backCaptureReady,
            hardwareCost: Double(session.hardwareCost),
            systemPressureCost: Double(session.systemPressureCost),
            recoveryAttempts: recoveryAttempt,
            inputCount: session.inputs.count,
            outputCount: session.outputs.count,
            connectionCount: session.connections.count,
            thermalState: String(describing: ProcessInfo.processInfo.thermalState),
            systemPressureState: devices.map { String(describing: $0.systemPressureState.level) }.joined(separator: ",")
        )
    }

    private func dumpFailureContext(reason: String) {
        #if DEBUG
        diagnosticPrint("ERROR", "reason=\(reason)")
        logDiagnostics(reason: reason)
        #endif
    }

    private func dumpSessionState(prefix: String) {
        #if DEBUG
        print("[DualCamera] \(prefix)")
        print("[DualCamera] isMultiCamSupported: \(AVCaptureMultiCamSession.isMultiCamSupported)")
        print("[DualCamera] inputs: \(session.inputs.count), outputs: \(session.outputs.count), connections: \(session.connections.count)")
        print("[DualCamera] hardwareCost: \(session.hardwareCost), systemPressureCost: \(session.systemPressureCost), isRunning: \(session.isRunning)")
        for (index, connection) in session.connections.enumerated() {
            let ports = connection.inputPorts.map { port in
                "media=\(port.mediaType.rawValue), position=\(port.sourceDevicePosition.rawValue)"
            }.joined(separator: "; ")
            let outputDescription = connection.output.map { String(describing: type(of: $0)) } ?? "previewLayer"
            print("[DualCamera] connection[\(index)] enabled=\(connection.isEnabled), active=\(connection.isActive), ports=[\(ports)], output=\(outputDescription)")
        }
        #endif
    }

    private func debugRuntimeError(_ snapshot: DualRuntimeErrorSnapshot) {
        #if DEBUG
        diagnosticPrint(
            "RUNTIME_ERROR",
            "avCode=\(snapshot.errorCode) domain=\(snapshot.error?.domain ?? "unknown") " +
            "code=\(snapshot.error?.code ?? 0) description=\(snapshot.error?.localizedDescription ?? "unknown") " +
            "userInfo=\(snapshot.error?.userInfo ?? snapshot.notificationUserInfo ?? [:])"
        )
        logDiagnostics(reason: "runtimeError")
        dumpSessionState(prefix: "runtime error state")
        #endif
    }

    private func debugLog(_ message: String, isError: Bool = false) {
        #if DEBUG
        diagnosticPrint(isError ? "ERROR" : "EVENT", message)
        #endif
    }

    private func diagnosticPrint(_ event: String, _ message: String) {
        #if DEBUG
        let milliseconds = Int(Date().timeIntervalSince1970 * 1_000)
        let thread = Thread.isMainThread ? "main" : "session"
        print("[DualCamera][\(diagnosticSessionID)][\(event)] t=\(milliseconds) thread=\(thread) state=\(state) generation=\(lifecycleGeneration) \(message)")
        #endif
    }
}

private nonisolated final class DualPreviewLayers: @unchecked Sendable {
    let back: AVCaptureVideoPreviewLayer
    let front: AVCaptureVideoPreviewLayer
    let attachmentID: UUID
    let previewID: String
    let generation: Int

    init(
        back: AVCaptureVideoPreviewLayer,
        front: AVCaptureVideoPreviewLayer,
        attachmentID: UUID = UUID(),
        previewID: String = "preserved",
        generation: Int = 0
    ) {
        self.back = back
        self.front = front
        self.attachmentID = attachmentID
        self.previewID = previewID
        self.generation = generation
    }
}

private nonisolated final class DualRuntimeErrorSnapshot: @unchecked Sendable {
    let error: NSError?
    let notificationUserInfo: [AnyHashable: Any]?

    init(error: NSError?, notificationUserInfo: [AnyHashable: Any]?) {
        self.error = error
        self.notificationUserInfo = notificationUserInfo
    }

    var errorCode: Int { error?.code ?? 0 }
    var isMediaServicesReset: Bool { errorCode == AVError.Code.mediaServicesWereReset.rawValue }
}

private nonisolated final class DualPhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let captureID: UUID
    let side: DualCameraSessionController.CameraSide
    let completion: @Sendable (UUID, DualCameraSessionController.CameraSide, Result<UIImage, Error>) -> Void

    init(
        captureID: UUID,
        side: DualCameraSessionController.CameraSide,
        completion: @escaping @Sendable (UUID, DualCameraSessionController.CameraSide, Result<UIImage, Error>) -> Void
    ) {
        self.captureID = captureID
        self.side = side
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            completion(captureID, side, .failure(LockUCameraError.dualCaptureFailed))
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            completion(captureID, side, .failure(LockUCameraError.invalidPhotoData))
            return
        }
        completion(captureID, side, .success(image))
    }
}

private nonisolated final class CameraSessionController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(
        label: "com.locku.camera.session",
        qos: .userInitiated
    )
    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var captureCompletion: ((Result<UIImage, Error>) -> Void)?

    func configure(
        position: AVCaptureDevice.Position,
        completion: @escaping @MainActor (Result<Void, Error>) -> Void
    ) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let result: Result<Void, Error>
            do {
                try self.configureSession(position: position)
                result = .success(())
            } catch {
                result = .failure(error)
            }
            Task { @MainActor in completion(result) }
        }
    }

    func start(completion: @escaping @MainActor (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            let running = self.session.isRunning
            Task { @MainActor in completion(running) }
        }
    }

    func stop(completion: @escaping @MainActor () -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            Task { @MainActor in completion() }
        }
    }

    func switchCamera(
        to position: AVCaptureDevice.Position,
        completion: @escaping @MainActor (Result<Void, Error>) -> Void
    ) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let result: Result<Void, Error>
            do {
                try self.replaceInput(position: position)
                result = .success(())
            } catch {
                result = .failure(error)
            }
            Task { @MainActor in completion(result) }
        }
    }

    func capturePhoto(
        flashEnabled: Bool,
        completion: @escaping @MainActor (Result<UIImage, Error>) -> Void
    ) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureCompletion = { result in
                Task { @MainActor in completion(result) }
            }
            let settings = AVCapturePhotoSettings()
            if flashEnabled, self.videoInput?.device.hasFlash == true {
                settings.flashMode = .on
            } else {
                settings.flashMode = .off
            }
            if let connection = self.photoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureSession(position: AVCaptureDevice.Position) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        let input = try makeInput(position: position)
        guard session.canAddInput(input) else { throw LockUCameraError.cannotAddInput }
        session.addInput(input)
        videoInput = input

        guard session.canAddOutput(photoOutput) else {
            session.removeInput(input)
            videoInput = nil
            throw LockUCameraError.cannotAddOutput
        }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
    }

    private func replaceInput(position: AVCaptureDevice.Position) throws {
        let newInput = try makeInput(position: position)
        let previousInput = videoInput

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if let previousInput {
            session.removeInput(previousInput)
        }
        guard session.canAddInput(newInput) else {
            if let previousInput, session.canAddInput(previousInput) {
                session.addInput(previousInput)
            }
            throw LockUCameraError.cannotAddInput
        }
        session.addInput(newInput)
        videoInput = newInput
    }

    private func makeInput(position: AVCaptureDevice.Position) throws -> AVCaptureDeviceInput {
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else {
            throw LockUCameraError.cameraUnavailable
        }
        do {
            return try AVCaptureDeviceInput(device: device)
        } catch {
            throw LockUCameraError.inputCreationFailed
        }
    }
}

extension CameraSessionController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            finishCapture(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            finishCapture(.failure(LockUCameraError.invalidPhotoData))
            return
        }
        finishCapture(.success(image))
    }

    private func finishCapture(_ result: Result<UIImage, Error>) {
        let completion = captureCompletion
        captureCompletion = nil
        completion?(result)
    }
}
