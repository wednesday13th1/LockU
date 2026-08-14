import AVFoundation
import SwiftUI
import UIKit

enum DualCameraPiPCorner: String, CaseIterable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
}

enum DualCameraPresentation: String {
    case backMain
    case frontMain
}

struct DualCameraOverlayLayout {
    let bounds: CGRect
    let safeAreaTop: CGFloat
    let safeAreaBottom: CGFloat

    var pipSize: CGSize {
        let width = min(118, max(96, bounds.width * 0.28))
        return CGSize(width: width, height: width * 1.25)
    }

    var pipTop: CGFloat { safeAreaTop + 78 }
    var lightControlTop: CGFloat { pipTop + pipSize.height + 28 }
    var captureClearance: CGFloat { max(162, safeAreaBottom + 146) }
    var availableLightControlHeight: CGFloat {
        max(248, bounds.height - lightControlTop - captureClearance)
    }
    var lightTrackHeight: CGFloat {
        min(240, max(94, availableLightControlHeight - 154))
    }
    var lightControlFrame: CGRect {
        CGRect(
            x: bounds.width - 16 - 76,
            y: lightControlTop,
            width: 76,
            height: lightTrackHeight + 154
        )
    }
    var topControlsFrame: CGRect {
        CGRect(x: 0, y: 0, width: bounds.width, height: safeAreaTop + 64)
    }
    var bottomControlsFrame: CGRect {
        CGRect(
            x: 0,
            y: bounds.height - captureClearance + 24,
            width: bounds.width,
            height: captureClearance - 24
        )
    }

    func pipFrame(for corner: DualCameraPiPCorner) -> CGRect {
        let leadingX: CGFloat = 18
        let trailingX = bounds.width - pipSize.width - 18
        let bottomY = bottomControlsFrame.minY - pipSize.height - 24
        switch corner {
        case .topLeading:
            return CGRect(origin: CGPoint(x: leadingX, y: pipTop), size: pipSize)
        case .topTrailing:
            return CGRect(origin: CGPoint(x: trailingX, y: pipTop), size: pipSize)
        case .bottomLeading:
            return CGRect(origin: CGPoint(x: leadingX, y: bottomY), size: pipSize)
        case .bottomTrailing:
            return CGRect(origin: CGPoint(x: trailingX, y: bottomY), size: pipSize)
        }
    }

    func nearestValidPiPCorner(from position: CGPoint) -> DualCameraPiPCorner {
        let validCorners = DualCameraPiPCorner.allCases.filter { isValidPiPCorner($0) }
        let candidates = validCorners.isEmpty ? [.topLeading] : validCorners
        return candidates.min { lhs, rhs in
            distanceSquared(from: position, to: pipFrame(for: lhs).center)
                < distanceSquared(from: position, to: pipFrame(for: rhs).center)
        } ?? .topLeading
    }

    private func isValidPiPCorner(_ corner: DualCameraPiPCorner) -> Bool {
        let frame = pipFrame(for: corner)
        let safeBounds = bounds.insetBy(dx: 16, dy: 0)
        let expandedLightFrame = lightControlFrame.insetBy(dx: -20, dy: -20)
        return safeBounds.contains(frame)
            && !frame.intersects(topControlsFrame)
            && !frame.intersects(expandedLightFrame)
            && !frame.intersects(bottomControlsFrame)
    }

    private func distanceSquared(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return (dx * dx) + (dy * dy)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

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
    let presentation: DualCameraPresentation
    let pipCorner: DualCameraPiPCorner
    let pipDragOffset: CGSize
    let isDraggingPiP: Bool
    let pipSnapToken: Int
    let presentationSwapToken: Int

    final class Coordinator {
        weak var view: DualCameraPreviewUIView?
        var attachmentID: UUID?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> DualCameraPreviewUIView {
        let view = DualCameraPreviewUIView(session: manager.dualSession)
        view.setPiPPlacement(
            presentation: presentation,
            corner: pipCorner,
            dragOffset: pipDragOffset,
            isDragging: isDraggingPiP,
            snapToken: pipSnapToken,
            presentationSwapToken: presentationSwapToken
        )
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
        uiView.setPiPPlacement(
            presentation: presentation,
            corner: pipCorner,
            dragOffset: pipDragOffset,
            isDragging: isDraggingPiP,
            snapToken: pipSnapToken,
            presentationSwapToken: presentationSwapToken
        )
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
    private let frontShadowLayer = CALayer()
    let diagnosticID = String(UUID().uuidString.prefix(4))
    private var lastReportedZeroFrame: Bool?
    private var pipCorner: DualCameraPiPCorner = .topTrailing
    private var presentation: DualCameraPresentation = .backMain
    private var pipDragOffset: CGSize = .zero
    private var isDraggingPiP = false
    private var lastPiPSnapToken = 0
    private var lastPresentationSwapToken = 0
    private var appliedPresentation: DualCameraPresentation?

    init(session: AVCaptureMultiCamSession) {
        backLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        frontLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        super.init(frame: .zero)
        backgroundColor = .black
        backLayer.videoGravity = .resizeAspectFill
        frontLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(backLayer)
        frontShadowLayer.backgroundColor = UIColor.black.withAlphaComponent(0.01).cgColor
        frontShadowLayer.shadowColor = UIColor.black.cgColor
        frontShadowLayer.shadowOpacity = 0.16
        frontShadowLayer.shadowRadius = 10
        frontShadowLayer.shadowOffset = CGSize(width: 0, height: 4)
        layer.addSublayer(frontShadowLayer)
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

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setNeedsLayout()
        if window != nil { updateFrames() }
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }

    func setPiPPlacement(
        presentation: DualCameraPresentation,
        corner: DualCameraPiPCorner,
        dragOffset: CGSize,
        isDragging: Bool,
        snapToken: Int,
        presentationSwapToken: Int
    ) {
        self.presentation = presentation
        pipCorner = corner
        pipDragOffset = dragOffset
        isDraggingPiP = isDragging
        let shouldAnimateSnap = snapToken != lastPiPSnapToken
        let shouldAnimateSwap = presentationSwapToken != lastPresentationSwapToken
        lastPiPSnapToken = snapToken
        lastPresentationSwapToken = presentationSwapToken
        updateFrames(animatePiP: shouldAnimateSnap || shouldAnimateSwap)
    }

    func updateFrames(animatePiP: Bool = false) {
        guard bounds.width > 0, bounds.height > 0 else {
            if lastReportedZeroFrame != true {
                lastReportedZeroFrame = true
                diagnosticLog(
                    "ZERO_FRAME",
                    detail: "back=\(backLayer.frame) front=\(frontLayer.frame) window=\(window != nil)"
                )
            }
            return
        }
        let layout = DualCameraOverlayLayout(
            bounds: bounds,
            safeAreaTop: safeAreaInsets.top,
            safeAreaBottom: safeAreaInsets.bottom
        )
        let baseFrame = layout.pipFrame(for: pipCorner)
        let frontFrame = baseFrame.offsetBy(dx: pipDragOffset.width, dy: pipDragOffset.height)
        let scale: CGFloat = isDraggingPiP ? 1.02 : 1
        let displayedFrame = frontFrame.scaled(around: frontFrame.center, by: scale)
        let mainLayer = presentation == .backMain ? backLayer : frontLayer
        let pipLayer = presentation == .backMain ? frontLayer : backLayer

        if appliedPresentation != presentation {
            layer.insertSublayer(mainLayer, at: 0)
            layer.insertSublayer(frontShadowLayer, above: mainLayer)
            layer.insertSublayer(pipLayer, above: frontShadowLayer)
            appliedPresentation = presentation
        }

        let applyFrame = {
            mainLayer.frame = self.bounds
            mainLayer.cornerRadius = 0
            mainLayer.borderWidth = 0
            self.frontShadowLayer.frame = displayedFrame
            pipLayer.frame = displayedFrame
            pipLayer.cornerRadius = 22
            pipLayer.borderWidth = 1.5
            pipLayer.borderColor = UIColor.white.withAlphaComponent(self.isDraggingPiP ? 0.94 : 0.78).cgColor
            self.frontShadowLayer.shadowOpacity = self.isDraggingPiP ? 0.23 : 0.16
        }
        if animatePiP {
            UIView.animate(
                withDuration: 0.24,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction],
                animations: applyFrame
            )
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            applyFrame()
            CATransaction.commit()
        }
        frontShadowLayer.cornerRadius = 22
        backLayer.masksToBounds = true
        frontLayer.masksToBounds = true

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

private extension CGRect {
    func scaled(around center: CGPoint, by scale: CGFloat) -> CGRect {
        let scaledSize = CGSize(width: width * scale, height: height * scale)
        return CGRect(
            x: center.x - (scaledSize.width / 2),
            y: center.y - (scaledSize.height / 2),
            width: scaledSize.width,
            height: scaledSize.height
        )
    }
}
