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

    func makeUIView(context: Context) -> DualCameraPreviewUIView {
        let view = DualCameraPreviewUIView(session: manager.dualSession)
        manager.connectDualPreview(backLayer: view.backLayer, frontLayer: view.frontLayer)
        return view
    }

    func updateUIView(_ uiView: DualCameraPreviewUIView, context: Context) {
        manager.connectDualPreview(backLayer: uiView.backLayer, frontLayer: uiView.frontLayer)
        uiView.updateFrames()
    }
}

final class DualCameraPreviewUIView: UIView {
    let backLayer: AVCaptureVideoPreviewLayer
    let frontLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureMultiCamSession) {
        backLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        frontLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        super.init(frame: .zero)
        backgroundColor = .black
        backLayer.videoGravity = .resizeAspectFill
        frontLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(backLayer)
        layer.addSublayer(frontLayer)
    }

    required init?(coder: NSCoder) { nil }

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
    }
}
