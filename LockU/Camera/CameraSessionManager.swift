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
        }
    }
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

    let session: AVCaptureSession
    private let controller: CameraSessionController

    init() {
        permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let controller = CameraSessionController()
        self.controller = controller
        session = controller.session
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
