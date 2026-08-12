import AVFoundation
import Combine
import UIKit

enum LockUCameraError: LocalizedError {
    case cameraUnavailable
    case inputCreationFailed
    case cannotAddInput
    case cannotAddOutput
    case captureFailed
    case invalidPhotoData
    case dualCaptureFailed

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
        }
    }
}

enum CameraSessionMode: Equatable {
    case single
    case dual
}

struct DualCameraCaptureResult {
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
    @Published private(set) var dualCapturedImages: DualCameraCaptureResult?

    let session: AVCaptureSession
    let dualSession: AVCaptureMultiCamSession
    private let controller: CameraSessionController
    private let dualController: DualCameraSessionController

    var supportsDualCamera: Bool { AVCaptureMultiCamSession.isMultiCamSupported }

    init() {
        permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let controller = CameraSessionController()
        let dualController = DualCameraSessionController()
        self.controller = controller
        self.dualController = dualController
        session = controller.session
        dualSession = dualController.session
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
            dualController.start { [weak self] running in self?.isSessionRunning = running }
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
        dualController.stop { }
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
        guard !isCapturing, isConfigured else { return }
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
        guard permissionStatus == .authorized else { return }
        guard supportsDualCamera else {
            sessionMode = .single
            startSession()
            completion?(false)
            return
        }
        controller.stop { [weak self] in
            guard let self else { return }
            self.isSessionRunning = false
            self.dualController.configure { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    self.sessionMode = .dual
                    self.dualController.start { [weak self] running in
                        self?.isSessionRunning = running
                        completion?(running)
                    }
                case .failure:
                    self.sessionMode = .single
                    self.errorMessage = "Dual Cameraを開始できませんでした。通常のカメラで撮影できます。"
                    self.configureAndStart()
                    completion?(false)
                }
            }
        }
    }

    func startDualSession() {
        guard supportsDualCamera else {
            sessionMode = .single
            startSession()
            return
        }
        prepareDualCamera()
    }

    func stopDualSession() {
        dualController.stop { [weak self] in
            guard let self else { return }
            self.isSessionRunning = false
            self.isCapturing = false
        }
    }

    func useSingleCamera() {
        dualController.stop { [weak self] in
            guard let self else { return }
            self.sessionMode = .single
            self.startSession()
        }
    }

    func captureDualPhoto() {
        guard sessionMode == .dual, isSessionRunning, !isCapturing else { return }
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

    func connectDualPreview(backLayer: AVCaptureVideoPreviewLayer, frontLayer: AVCaptureVideoPreviewLayer) {
        dualController.connectPreview(backLayer: backLayer, frontLayer: frontLayer)
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
}

private nonisolated final class DualCameraSessionController: NSObject, @unchecked Sendable {
    enum CameraSide: Hashable { case front, back }

    let session = AVCaptureMultiCamSession()
    private let sessionQueue = DispatchQueue(label: "com.locku.camera.dual.session", qos: .userInitiated)
    private let processingQueue = DispatchQueue(label: "com.locku.camera.dual.processing", qos: .userInitiated)
    private let frontOutput = AVCapturePhotoOutput()
    private let backOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var activeCaptureID: UUID?
    private var pendingImages: [CameraSide: UIImage] = [:]
    private var delegates: [CameraSide: DualPhotoDelegate] = [:]
    private var captureCompletion: (@MainActor (Result<DualCameraCaptureResult, Error>) -> Void)?
    private var timeoutWorkItem: DispatchWorkItem?
    private var previewConnections: [AVCaptureConnection] = []
    private weak var connectedBackLayer: AVCaptureVideoPreviewLayer?
    private weak var connectedFrontLayer: AVCaptureVideoPreviewLayer?

    func configure(completion: @escaping @MainActor (Result<Void, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.isConfigured {
                Task { @MainActor in completion(.success(())) }
                return
            }
            do {
                try self.configureSession()
                self.isConfigured = true
                Task { @MainActor in completion(.success(())) }
            } catch {
                self.resetConfiguration()
                Task { @MainActor in completion(.failure(error)) }
            }
        }
    }

    func start(completion: @escaping @MainActor (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning { self.session.startRunning() }
            let running = self.session.isRunning
            Task { @MainActor in completion(running) }
        }
    }

    func stop(completion: @escaping @MainActor () -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.cancelCapture(with: LockUCameraError.dualCaptureFailed, notify: false)
            if self.session.isRunning { self.session.stopRunning() }
            Task { @MainActor in completion() }
        }
    }

    func capture(completion: @escaping @MainActor (Result<DualCameraCaptureResult, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isConfigured, self.session.isRunning, self.activeCaptureID == nil else {
                Task { @MainActor in completion(.failure(LockUCameraError.dualCaptureFailed)) }
                return
            }
            let captureID = UUID()
            self.activeCaptureID = captureID
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

    func connectPreview(backLayer: AVCaptureVideoPreviewLayer, frontLayer: AVCaptureVideoPreviewLayer) {
        let layers = DualPreviewLayers(back: backLayer, front: frontLayer)
        sessionQueue.async { [weak self, layers] in
            guard let self, self.isConfigured else { return }
            let backLayer = layers.back
            let frontLayer = layers.front
            guard self.connectedBackLayer !== backLayer
                    || self.connectedFrontLayer !== frontLayer
                    || self.previewConnections.count != 2 else { return }
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }
            self.previewConnections.forEach { self.session.removeConnection($0) }
            self.previewConnections = []
            guard let frontInput = self.session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first(where: { $0.device.position == .front }),
                  let backInput = self.session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first(where: { $0.device.position == .back }) else { return }
            if let front = self.makePreviewConnection(input: frontInput, layer: frontLayer, mirrored: true),
               let back = self.makePreviewConnection(input: backInput, layer: backLayer, mirrored: false) {
                self.previewConnections = [front, back]
                self.connectedBackLayer = backLayer
                self.connectedFrontLayer = frontLayer
            }
        }
    }

    private func configureSession() throws {
        guard AVCaptureMultiCamSession.isMultiCamSupported else { throw LockUCameraError.cameraUnavailable }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let frontInput = try makeInput(position: .front)
        let backInput = try makeInput(position: .back)
        guard session.canAddInput(frontInput), session.canAddInput(backInput) else { throw LockUCameraError.cannotAddInput }
        session.addInputWithNoConnections(frontInput)
        session.addInputWithNoConnections(backInput)
        guard session.canAddOutput(frontOutput), session.canAddOutput(backOutput) else { throw LockUCameraError.cannotAddOutput }
        session.addOutputWithNoConnections(frontOutput)
        session.addOutputWithNoConnections(backOutput)

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
        guard session.canAddConnection(connection) else { throw LockUCameraError.cannotAddOutput }
        session.addConnection(connection)
    }

    private func makeInput(position: AVCaptureDevice.Position) throws -> AVCaptureDeviceInput {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw LockUCameraError.cameraUnavailable
        }
        do { return try AVCaptureDeviceInput(device: device) }
        catch { throw LockUCameraError.inputCreationFailed }
    }

    private func prepareConnection(_ connection: AVCaptureConnection?) {
        guard let connection else { return }
        if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }

    private func makePreviewConnection(
        input: AVCaptureDeviceInput,
        layer: AVCaptureVideoPreviewLayer,
        mirrored: Bool
    ) -> AVCaptureConnection? {
        guard let port = input.ports.first(where: { $0.mediaType == .video && $0.sourceDevicePosition == input.device.position }) else { return nil }
        let connection = AVCaptureConnection(inputPort: port, videoPreviewLayer: layer)
        guard session.canAddConnection(connection) else { return nil }
        if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
        session.addConnection(connection)
        return connection
    }

    private func receive(captureID: UUID, side: CameraSide, result: Result<UIImage, Error>) {
        sessionQueue.async { [weak self] in
            guard let self, self.activeCaptureID == captureID else { return }
            switch result {
            case .failure:
                self.cancelCapture(with: LockUCameraError.dualCaptureFailed, notify: true)
            case .success(let image):
                self.pendingImages[side] = image
                guard let front = self.pendingImages[.front], let back = self.pendingImages[.back] else { return }
                self.timeoutWorkItem?.cancel()
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

    private func resetConfiguration() {
        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        previewConnections = []
        connectedBackLayer = nil
        connectedFrontLayer = nil
        session.commitConfiguration()
        isConfigured = false
    }
}

private nonisolated final class DualPreviewLayers: @unchecked Sendable {
    let back: AVCaptureVideoPreviewLayer
    let front: AVCaptureVideoPreviewLayer

    init(back: AVCaptureVideoPreviewLayer, front: AVCaptureVideoPreviewLayer) {
        self.back = back
        self.front = front
    }
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
