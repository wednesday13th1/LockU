import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct CameraCaptureView: View {
    @EnvironmentObject private var appModel: LockUAppModel
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var decorationRepository: DecorationRepository
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = CameraSessionManager()
    @StateObject private var editor = MemoryEditorViewModel()
    @State private var reviewMode: CaptureMode = .camera
    @State private var isSaving = false
    @State private var flashOverlay = false

    private var capturedToday: Bool {
        memoryRepository.hasMemory(on: .now)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let originalImage = editor.originalImage {
                CameraReviewView(
                    originalImage: originalImage,
                    cutoutImage: editor.cutoutImage,
                    selectedStyle: $editor.selectedStyle,
                    captureMode: reviewMode,
                    isExtracting: editor.isExtracting,
                    isSaving: isSaving,
                    cutoutErrorMessage: editor.cutoutErrorMessage,
                    onClose: closeEditor,
                    onExtractSubject: editor.extractSubject,
                    onRetake: retake,
                    onSave: save
                )
            } else if capturedToday {
                alreadyCapturedView
            } else {
                cameraContent
            }
        }
        .onAppear {
            appModel.isCameraPresented = true
            if !capturedToday { camera.prepare() }
        }
        .onDisappear {
            appModel.isCameraPresented = false
            camera.stopSession()
            editor.clear()
        }
        .onChange(of: camera.capturedImage) { _, image in
            guard let image else { return }
            reviewMode = .camera
            editor.reset(with: image)
        }
        .onChange(of: camera.permissionStatus) { _, status in
            appModel.cameraPermissionDenied = status == .denied || status == .restricted
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if editor.originalImage == nil, !capturedToday { camera.startSession() }
            case .inactive, .background:
                camera.stopSession()
            @unknown default:
                camera.stopSession()
            }
        }
        .alert(
            "Camera",
            isPresented: Binding(
                get: { camera.errorMessage != nil },
                set: { if !$0 { camera.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { camera.errorMessage = nil }
        } message: {
            Text(camera.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var cameraContent: some View {
        switch camera.permissionStatus {
        case .denied, .restricted:
            CameraPermissionView(
                isRestricted: camera.permissionStatus == .restricted,
                onLibraryImage: receiveLibraryImage,
                onError: { appModel.report($0) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LockUDesign.Color.paperCream)
        case .authorized:
            liveCamera
        case .notDetermined:
            ProgressView("カメラを準備しています…")
                .tint(.white)
                .foregroundStyle(.white)
        @unknown default:
            Text("カメラを利用できません").foregroundStyle(.white)
        }
    }

    private var liveCamera: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea(edges: .top)

            if !camera.isSessionRunning {
                ProgressView().tint(.white)
            }

            VStack {
                topControls
                Spacer()
                bottomControls
            }

            Color.white
                .opacity(flashOverlay ? 0.8 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.16), value: flashOverlay)
        }
    }

    private var topControls: some View {
        HStack {
            cameraCircleButton(icon: "xmark") {
                appModel.selectedTab = .locker
            }
            .accessibilityLabel("撮影を閉じる")
            Spacer()
            cameraCircleButton(icon: "camera.rotate") {
                camera.switchCamera()
            }
            .rotationEffect(.degrees(camera.isSwitching ? 180 : 0))
            .animation(LockUDesign.Motion.soft, value: camera.isSwitching)
            .disabled(camera.isSwitching || camera.isCapturing)
            .accessibilityLabel("内カメラと外カメラを切り替える")
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var bottomControls: some View {
        ZStack {
            HStack {
                PhotoLibraryPicker(
                    isDisabled: camera.isCapturing,
                    onImage: receiveLibraryImage,
                    onError: { appModel.report($0) }
                )
                Spacer()
                if camera.currentPosition == .back {
                    cameraCircleButton(
                        icon: camera.isFlashEnabled ? "bolt.fill" : "bolt.slash.fill"
                    ) {
                        camera.isFlashEnabled.toggle()
                    }
                    .accessibilityLabel(camera.isFlashEnabled ? "フラッシュを切る" : "フラッシュを入れる")
                } else {
                    Color.clear.frame(width: 46, height: 46)
                }
            }
            .padding(.horizontal, 22)

            Button {
                flashOverlay = true
                camera.capturePhoto()
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    flashOverlay = false
                }
            } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                    Circle().fill(LockUDesign.Color.cameraCream).frame(width: 62, height: 62)
                }
            }
            .buttonStyle(ShutterButtonStyle())
            .disabled(camera.isCapturing || !camera.isSessionRunning)
            .opacity(camera.isSessionRunning ? 1 : 0.5)
            .accessibilityLabel("写真を撮影")
        }
        .padding(.top, 18)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var alreadyCapturedView: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(LockUDesign.Color.accent)
                .frame(width: 68, height: 68)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }
                .shadow(color: LockUDesign.Color.accent.opacity(0.22), radius: 14, y: 7)
            if let memory = memoryRepository.memories.first,
               let image = memoryRepository.image(for: memory) {
                VStack(spacing: 0) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 128, height: 145)
                        .clipped()
                    Color.clear.frame(height: 16)
                }
                .padding(6)
                .background(LockUDesign.Color.surface)
                .rotationEffect(.degrees(-1.5))
                .shadow(color: .black.opacity(0.045), radius: 3, y: 1)
                .shadow(color: .black.opacity(0.08), radius: 14, y: 7)
            }
            Text("今日の思い出")
                .font(LockUDesign.Typography.screenTitle)
            Text("ロッカーに追加されました！")
                .font(LockUDesign.Typography.body)
                .foregroundStyle(LockUDesign.Color.textSecondary)
            Button("ロッカーを見る") {
                appModel.lockerDoorState = .open
                appModel.selectedTab = .locker
            }
            .buttonStyle(LockUPrimaryButtonStyle())
            Button("思い出を見る") {
                appModel.selectedTab = .book
            }
            .buttonStyle(LockUSecondaryButtonStyle())
            Text("明日もお楽しみに！")
                .font(LockUDesign.Typography.caption)
                .foregroundStyle(LockUDesign.Color.textSecondary)
        }
        .padding(24)
        .frame(maxWidth: 380)
        .foregroundStyle(LockUDesign.Color.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SkyBackground())
    }

    private func cameraCircleButton(
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
        }
        .buttonStyle(LockUCameraControlStyle())
    }

    private func receiveLibraryImage(_ image: UIImage) {
        camera.stopSession()
        reviewMode = .photoLibrary
        editor.reset(with: image)
    }

    private func retake() {
        editor.clear()
        camera.capturedImage = nil
        camera.startSession()
    }

    private func closeEditor() {
        editor.clear()
        camera.capturedImage = nil
        appModel.selectedTab = .locker
    }

    private func save() {
        guard let image = editor.imageToSave, !isSaving else { return }
        let imageStyle = editor.selectedStyle
        isSaving = true
        do {
            _ = try memoryRepository.saveImage(
                image,
                createdAt: .now,
                filterID: nil,
                weather: nil,
                captureMode: reviewMode,
                imageStyle: imageStyle
            )
            if imageStyle == .cutout {
                do {
                    _ = try decorationRepository.add(
                        image: image,
                        initialPosition: CodablePoint(x: 0.5, y: 0.52),
                        initialScale: 0.8
                    )
                } catch {
                    appModel.presentedError =
                        "思い出は保存しましたが、ロッカーへの配置に失敗しました。\n\(error.localizedDescription)"
                }
            }
            camera.capturedImage = nil
            editor.clear()
            isSaving = false
            appModel.selectedCapturedImage = image
            appModel.lockerDoorState = .open
            appModel.selectedTab = .locker
        } catch {
            isSaving = false
            appModel.report(error)
        }
    }
}

private struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(LockUDesign.Motion.quick, value: configuration.isPressed)
    }
}

#Preview("Camera Review") {
    CameraReviewView(
        originalImage: UIImage(systemName: "photo") ?? UIImage(),
        cutoutImage: nil,
        selectedStyle: .constant(.original),
        captureMode: .camera,
        isExtracting: false,
        isSaving: false,
        cutoutErrorMessage: nil,
        onClose: {},
        onExtractSubject: {},
        onRetake: {},
        onSave: {}
    )
}

#Preview("Camera Review Extracting") {
    CameraReviewView(
        originalImage: UIImage(systemName: "photo") ?? UIImage(),
        cutoutImage: nil,
        selectedStyle: .constant(.original),
        captureMode: .photoLibrary,
        isExtracting: true,
        isSaving: false,
        cutoutErrorMessage: nil,
        onClose: {},
        onExtractSubject: {},
        onRetake: {},
        onSave: {}
    )
}

#Preview("Camera Review Error") {
    CameraReviewView(
        originalImage: UIImage(systemName: "photo") ?? UIImage(),
        cutoutImage: nil,
        selectedStyle: .constant(.original),
        captureMode: .camera,
        isExtracting: false,
        isSaving: false,
        cutoutErrorMessage: "切り抜ける被写体を見つけられませんでした。",
        onClose: {},
        onExtractSubject: {},
        onRetake: {},
        onSave: {}
    )
}
