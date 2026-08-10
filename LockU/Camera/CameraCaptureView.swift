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
    @State private var dailyFilm = DailyFilmService().film(for: .now)
    @State private var showFilmReveal = false
    @State private var captureHasDailyFilm = false

    private let dailyFilmService = DailyFilmService()
    private let revealStore = DailyFilmRevealStore()

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
            refreshDailyFilm(allowReveal: true)
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
            let film = dailyFilm
            Task {
                let processed = await DailyFilmRenderer.shared.renderAsync(image, film: film) ?? image
                guard camera.capturedImage != nil else { return }
                captureHasDailyFilm = true
                editor.reset(with: processed)
            }
        }
        .onChange(of: camera.permissionStatus) { _, status in
            appModel.cameraPermissionDenied = status == .denied || status == .restricted
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                refreshDailyFilm(allowReveal: false)
                if editor.originalImage == nil, !capturedToday { camera.startSession() }
            case .inactive, .background:
                camera.stopSession()
            @unknown default:
                camera.stopSession()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshDailyFilm(allowReveal: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshDailyFilm(allowReveal: false)
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
                .dailyFilmPreview(dailyFilm)

            if !camera.isSessionRunning {
                ProgressView().tint(.white)
            }

            VStack {
                topControls
                Spacer()
                bottomControls
            }

            if showFilmReveal {
                filmReveal
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            Color.white
                .opacity(flashOverlay ? 0.8 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.16), value: flashOverlay)
        }
    }

    private var topControls: some View {
        VStack(spacing: 8) {
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

            VStack(spacing: 1) {
                Text("TODAY'S FILM")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.6)
                Text(dailyFilm.name)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.8)
            }
            .foregroundStyle(.white.opacity(0.88))
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            .accessibilityElement(children: .combine)
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
        captureHasDailyFilm = false
        editor.reset(with: image)
    }

    private func retake() {
        editor.clear()
        camera.capturedImage = nil
        captureHasDailyFilm = false
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
                imageStyle: imageStyle,
                dailyFilm: captureHasDailyFilm && reviewMode == .camera ? dailyFilm : nil
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

    private var filmReveal: some View {
        VStack(spacing: 8) {
            Text("TODAY'S FILM")
                .font(.system(size: 10, weight: .medium))
                .tracking(2.2)
            Text(dailyFilm.name)
                .font(.system(size: 24, weight: .semibold))
                .tracking(1.2)
            if let subtitle = dailyFilm.subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .opacity(0.72)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
        .allowsHitTesting(false)
    }

    private func refreshDailyFilm(allowReveal: Bool) {
        let now = Date.now
        dailyFilm = dailyFilmService.film(for: now)
        guard allowReveal, revealStore.shouldReveal(on: now, service: dailyFilmService) else { return }
        revealStore.markRevealed(on: now, service: dailyFilmService)
        withAnimation(.easeOut(duration: 0.24)) { showFilmReveal = true }
        Task {
            try? await Task.sleep(for: .seconds(1.05))
            withAnimation(.easeIn(duration: 0.28)) { showFilmReveal = false }
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
