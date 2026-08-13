import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
        uiView.updateConnection()
    }
}

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateConnection()
    }

    func updateConnection() {
        guard let connection = previewLayer.connection else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }
}

struct DualCameraPreviewView: UIViewRepresentable {
    @ObservedObject var manager: CameraSessionManager

    final class Coordinator {
        weak var view: DualCameraPreviewUIView?
        var attachmentID: UUID?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> DualCameraPreviewUIView {
        let view = DualCameraPreviewUIView(session: manager.dualSession)
        context.coordinator.view = view
        context.coordinator.attachmentID = manager.connectDualPreview(
            backLayer: view.backLayer,
            frontLayer: view.frontLayer,
            previewID: view.diagnosticID
        )
        view.installDisconnectHandler { [weak manager, weak view] attachmentID in
            guard let manager, let view else { return }
            manager.disconnectDualPreview(
                backLayer: view.backLayer,
                frontLayer: view.frontLayer,
                attachmentID: attachmentID,
                previewID: view.diagnosticID
            )
        }
        return view
    }

    func updateUIView(_ uiView: DualCameraPreviewUIView, context: Context) {
        uiView.updateFrames()
    }

    static func dismantleUIView(_ uiView: DualCameraPreviewUIView, coordinator: Coordinator) {
        guard coordinator.view === uiView, let attachmentID = coordinator.attachmentID else { return }
        uiView.diagnosticLog("DISCONNECT")
        // The controller verifies both the attachment token and lifecycle generation. A stale
        // SwiftUI host can therefore never detach the replacement preview.
        uiView.detachPreview(attachmentID: attachmentID)
        coordinator.attachmentID = nil
        coordinator.view = nil
    }
}

final class DualCameraPreviewUIView: UIView {
    let backLayer: AVCaptureVideoPreviewLayer
    let frontLayer: AVCaptureVideoPreviewLayer
    let diagnosticID = String(UUID().uuidString.prefix(4))
    private var lastReportedZeroFrame: Bool?

    init(session: AVCaptureMultiCamSession) {
        backLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        frontLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        super.init(frame: .zero)
        backgroundColor = .black
        backLayer.videoGravity = .resizeAspectFill
        frontLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(backLayer)
        layer.addSublayer(frontLayer)
        diagnosticLog("CREATED")
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        #if DEBUG
        print("[DualCamera][Preview][\(diagnosticID)][DEINIT]")
        #endif
    }

    private var disconnectHandler: ((UUID) -> Void)?

    func installDisconnectHandler(_ handler: @escaping (UUID) -> Void) {
        disconnectHandler = handler
    }

    func detachPreview(attachmentID: UUID) {
        disconnectHandler?(attachmentID)
        disconnectHandler = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateFrames()
    }

    func updateFrames() {
        backLayer.frame = bounds
        let width = bounds.width * 0.28
        let height = width * 1.25
        frontLayer.frame = CGRect(x: bounds.width - width - 18, y: safeAreaInsets.top + 78, width: width, height: height)
        frontLayer.cornerRadius = 14
        frontLayer.masksToBounds = true
        frontLayer.borderWidth = 1
        frontLayer.borderColor = UIColor.white.withAlphaComponent(0.72).cgColor
        frontLayer.shadowColor = UIColor.black.cgColor
        frontLayer.shadowOpacity = 0.18
        frontLayer.shadowRadius = 6
        frontLayer.shadowOffset = CGSize(width: 0, height: 3)

        let hasZeroFrame = backLayer.frame.isEmpty || frontLayer.frame.isEmpty
        if lastReportedZeroFrame != hasZeroFrame {
            lastReportedZeroFrame = hasZeroFrame
            diagnosticLog(
                hasZeroFrame ? "ZERO_FRAME" : "FRAME_READY",
                detail: "back=\(backLayer.frame) front=\(frontLayer.frame) window=\(window != nil)"
            )
        }
    }

    func diagnosticLog(_ event: String, detail: String = "") {
        #if DEBUG
        print("[DualCamera][Preview][\(diagnosticID)][\(event)] \(detail)")
        #endif
    }
}
