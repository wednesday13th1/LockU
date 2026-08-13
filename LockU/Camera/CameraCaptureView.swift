import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

private enum LockUCaptureExperience: Equatable {
    case single
    case dual
}

struct CameraCaptureView: View {
    @EnvironmentObject private var appModel: LockUAppModel
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var decorationRepository: DecorationRepository
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var camera = CameraSessionManager()
    @StateObject private var editor = MemoryEditorViewModel()
    @State private var reviewMode: CaptureMode = .camera
    @State private var isSaving = false
    @State private var flashOverlay = false
    @State private var dailyFilm = DailyFilmService().film(for: .now)
    @State private var showFilmReveal = false
    @State private var captureHasDailyFilm = false
    @State private var captureExperience: LockUCaptureExperience = .single
    @State private var isSavingDualMemory = false
    @State private var isLightControlVisible = false
    @State private var isAdjustingLight = false
    @State private var lightDragStartLevel: Double = 50
    @State private var lightDismissTask: Task<Void, Never>?

    private let dailyFilmService = DailyFilmService()
    private let revealStore = DailyFilmRevealStore()

    private var capturedToday: Bool {
        memoryRepository.hasMemory(on: Date.now)
    }

    var body: some View {
        observedCameraRoot
            .modifier(CameraErrorAlertModifier(errorMessage: $camera.errorMessage))
    }

    private var cameraRoot: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            activeCameraContent
        }
    }

    private var activeCameraContent: AnyView {
        if let result = camera.dualCapturedImages { return dualReview(result) }
        if let original = editor.originalImage { return photoReview(original) }
        if capturedToday { return AnyView(alreadyCapturedView) }
        return cameraContent
    }

    private func dualReview(_ result: DualCameraCaptureResult) -> AnyView {
        AnyView(DualCameraReviewView(
            result: result,
            isSaving: isSavingDualMemory,
            onClose: closeDualReview,
            onRetake: retakeDual,
            onSave: { saveDual(result: result) }
        ))
    }

    private func photoReview(_ original: UIImage) -> AnyView {
        AnyView(CameraReviewView(
            originalImage: original,
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
        ))
    }

    private var observedCameraRoot: some View {
        cameraRoot
            .modifier(CameraAppearanceEvents(
                onAppear: handleCameraAppear,
                onDisappear: handleCameraDisappear
            ))
            .modifier(CameraStateEvents(
                capturedImage: camera.capturedImage,
                permissionStatus: camera.permissionStatus,
                scenePhase: scenePhase,
                onCapturedImage: handleCapturedImage,
                onPermission: handlePermissionChange,
                onScenePhase: handleScenePhaseChange
            ))
            .modifier(CameraCalendarEvents(onRefresh: handleCalendarRefresh))
    }

    private func handleCameraAppear() {
        appModel.setCameraPresented(true)
        camera.setCameraScreenActive(true)
        camera.setApplicationActive(scenePhase == .active)
        refreshDailyFilm(allowReveal: true)
        if !capturedToday { camera.prepare() }
    }

    private func handleCameraDisappear() {
        appModel.setCameraPresented(false)
        camera.setCameraScreenActive(false)
        camera.setApplicationActive(false)
        camera.stopSession()
        editor.clear()
        camera.clearDualCapture()
        lightDismissTask?.cancel()
        lightDismissTask = nil
        isLightControlVisible = false
        isAdjustingLight = false
    }

    private func handlePermissionChange(_ status: AVAuthorizationStatus) {
        appModel.cameraPermissionDenied = status == .denied || status == .restricted
    }

    private func handleCalendarRefresh() {
        refreshDailyFilm(allowReveal: false)
    }

    private func handleCapturedImage(_ image: UIImage?) {
        guard let image else { return }
        reviewMode = .camera
        let film = dailyFilm

        Task { @MainActor in
            let renderedImage = await DailyFilmRenderer.shared.renderAsync(image, film: film)
            guard camera.capturedImage != nil else { return }
            captureHasDailyFilm = true
            editor.reset(with: renderedImage ?? image)
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        camera.setApplicationActive(phase == .active)
        guard phase == .active else {
            camera.stopSession()
            return
        }

        refreshDailyFilm(allowReveal: false)
        guard editor.originalImage == nil, !capturedToday else { return }

        if captureExperience == .dual {
            guard camera.dualCapturedImages == nil else { return }
            activateDualMode()
        } else {
            camera.startSession()
        }
    }

    private var cameraContent: AnyView {
        switch camera.permissionStatus {
        case .denied, .restricted:
            return AnyView(CameraPermissionView(
                isRestricted: camera.permissionStatus == .restricted,
                onClose: { appModel.selectedTab = .locker },
                onLibraryImage: receiveLibraryImage,
                onError: { appModel.report($0) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LockUDesign.Color.paperCream))
        case .authorized:
            return AnyView(liveCamera)
        case .notDetermined:
            return AnyView(ProgressView("カメラを準備しています…")
                .tint(.white)
                .foregroundStyle(.white))
        @unknown default:
            return AnyView(Text("カメラを利用できません").foregroundStyle(.white))
        }
    }

    private var liveCamera: some View {
        ZStack {
            if captureExperience == .dual {
                DualCameraPreviewView(manager: camera)
                    .ignoresSafeArea(edges: .top)
                    .opacity(dualPreviewIsVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.16), value: dualPreviewIsVisible)
                    .accessibilityLabel("見ている景色と、その時の自分のカメラプレビュー")
            } else {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea(edges: .top)
                    .dailyFilmPreview(dailyFilm)
            }


            if captureExperience == .dual {
                DualCameraLightControl(
                    level: camera.lightLevel,
                    isExpanded: isLightControlVisible,
                    isEnabled: camera.dualCameraUXState == .ready,
                    reduceMotion: reduceMotion,
                    onTap: handleLightControlTap,
                    onDragChanged: updateLightFromIconDrag,
                    onDragEnded: finishLightAdjustment,
                    onSliderChanged: updateLightFromSlider,
                    onSliderEnded: finishLightAdjustment
                )
                .padding(.top, 8)
                .padding(.trailing, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(15)
            }

            if captureExperience == .dual, isAdjustingLight {
                LightPercentageHUD(level: camera.lightLevel)
                    .zIndex(14)
            }

            if captureExperience == .dual, !dualPreviewIsVisible {
                DualCameraPreparingSurface(showProgress: dualShowsProgress)
                    .transition(.opacity)
                    .zIndex(5)
            } else if captureExperience == .single, !camera.isSessionRunning {
                ProgressView().tint(.white)
            }

            if captureExperience == .dual, dualShowsFailure {
                VStack(spacing: 14) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24, weight: .medium))
                    Text("Camera unavailable")
                        .font(.system(size: 17, weight: .semibold))
                    HStack(spacing: 12) {
                        Button("Close") { appModel.selectedTab = .locker }
                        if camera.dualCameraUXState != .unsupported {
                            Button("Retry") { camera.retryDualCamera() }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .foregroundStyle(.white)
                .padding(22)
                .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 16))
                .zIndex(20)
            }

            if captureExperience == .dual {
                Text("WHAT YOU SAW")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.82))
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 66)
                    .accessibilityLabel("見ていた景色")

                Text("YOU")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.28), in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 91)
                    .padding(.trailing, 24)
                    .accessibilityLabel("その時の自分")
            }

            VStack {
                topControls
                Spacer()
                bottomControls
            }
            .zIndex(10)

            if showFilmReveal && captureExperience == .single {
                filmReveal
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            Color.white
                .opacity(flashOverlay ? 0.8 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.16), value: flashOverlay)
        }
        .onChange(of: camera.dualCameraUXState) { _, state in
            if state == .ready { camera.markDualPreviewVisible() }
        }
    }

    private var dualPreviewIsVisible: Bool {
        camera.dualCameraUXState == .ready || camera.dualCameraUXState == .capturing
    }

    private var dualShowsProgress: Bool {
        switch camera.dualCameraUXState {
        case .preparing, .interrupted, .recovering: true
        default: false
        }
    }

    private var dualShowsFailure: Bool {
        camera.dualCameraUXState == .failed || camera.dualCameraUXState == .unsupported
    }

    private func showLightControl() {
        guard camera.dualCameraUXState == .ready else { return }
        lightDismissTask?.cancel()
        lightDismissTask = nil
        lightDragStartLevel = camera.lightLevel
        let animation = reduceMotion ? nil : Animation.easeOut(duration: 0.16)
        withAnimation(animation) { isLightControlVisible = true }
    }

    private func handleLightControlTap() {
        showLightControl()
        scheduleLightControlDismissal()
    }

    private func updateLightFromIconDrag(_ translation: CGSize) {
        guard camera.dualCameraUXState == .ready else { return }
        if !isAdjustingLight {
            lightDragStartLevel = camera.lightLevel
            showLightControl()
            isAdjustingLight = true
        }
        camera.setLightLevel(lightDragStartLevel - Double(translation.height / 180) * 100)
    }

    private func updateLightFromSlider(_ level: Double) {
        guard camera.dualCameraUXState == .ready else { return }
        lightDismissTask?.cancel()
        isAdjustingLight = true
        camera.setLightLevel(level)
    }

    private func finishLightAdjustment() {
        guard isLightControlVisible else { return }
        camera.setLightLevel(camera.lightLevel, isFinal: true)
        isAdjustingLight = false
        scheduleLightControlDismissal()
    }

    private func scheduleLightControlDismissal() {
        lightDismissTask?.cancel()
        lightDismissTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(450))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let animation = reduceMotion ? nil : Animation.easeIn(duration: 0.22)
            withAnimation(animation) { isLightControlVisible = false }
            lightDismissTask = nil
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
                if captureExperience == .single {
                    cameraCircleButton(icon: "camera.rotate") {
                        camera.switchCamera()
                    }
                    .rotationEffect(.degrees(camera.isSwitching ? 180 : 0))
                    .animation(LockUDesign.Motion.soft, value: camera.isSwitching)
                    .disabled(camera.isSwitching || camera.isCapturing)
                    .accessibilityLabel("内カメラと外カメラを切り替える")
                }
            }

            if captureExperience == .single {
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
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var bottomControls: some View {
        VStack(spacing: 13) {
            if camera.supportsDualCamera {
                captureModeSelector
            }

            ZStack {
                if captureExperience == .single {
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
                }

                Button {
                        flashOverlay = true
                        if captureExperience == .dual { camera.captureDualPhoto() }
                        else { camera.capturePhoto() }
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
                    .disabled(!camera.canCapture)
                    .opacity(camera.canCapture ? 1 : 0.5)
                    .accessibilityLabel(captureExperience == .dual ? "景色と自分を同時に撮影" : "写真を撮影")
            }
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

    private var captureModeSelector: some View {
        HStack(spacing: 26) {
            modeButton("PHOTO", experience: .single)
            modeButton("DUAL", experience: .dual)
        }
        .disabled(camera.isCapturing)
        .accessibilityElement(children: .contain)
    }

    private func modeButton(_ title: String, experience: LockUCaptureExperience) -> some View {
        Button {
            guard captureExperience != experience else { return }
            if reduceMotion { captureExperience = experience }
            else { withAnimation(.easeInOut(duration: 0.24)) { captureExperience = experience } }
            if experience == .dual { activateDualMode() }
            else {
                camera.clearDualCapture()
                camera.useSingleCamera()
            }
        } label: {
            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                Rectangle()
                    .fill(.white.opacity(captureExperience == experience ? 0.95 : 0))
                    .frame(height: 1)
            }
            .foregroundStyle(.white.opacity(captureExperience == experience ? 1 : 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(captureExperience == experience ? .isSelected : [])
    }

    private func activateDualMode() {
        camera.startDualSession { started in
            guard !started else { return }
            if reduceMotion { captureExperience = .single }
            else { withAnimation(.easeInOut(duration: 0.2)) { captureExperience = .single } }
        }
    }

    private func retakeDual() {
        guard !isSavingDualMemory else { return }
        camera.retakeDualCapture()
    }

    private func closeDualReview() {
        guard !isSavingDualMemory else { return }
        camera.clearDualCapture()
        appModel.selectedTab = .locker
    }

    private func saveDual(result: DualCameraCaptureResult) {
        guard !isSavingDualMemory else { return }
        isSavingDualMemory = true
        do {
            let memory = try memoryRepository.saveDualCameraMemory(
                frontImage: result.frontImage,
                backImage: result.backImage,
                createdAt: .now
            )
            camera.clearDualCapture()
            isSavingDualMemory = false
            appModel.selectedCapturedImage = memoryRepository.image(for: memory)
            appModel.lockerDoorState = .open
            appModel.selectedTab = .locker
        } catch {
            isSavingDualMemory = false
            appModel.report(error)
        }
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

private struct CameraErrorAlertModifier: ViewModifier {
    @Binding var errorMessage: String?

    func body(content: Content) -> some View {
        content.alert(
            "Camera",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}

private struct CameraAppearanceEvents: ViewModifier {
    let onAppear: () -> Void
    let onDisappear: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear(perform: onAppear)
            .onDisappear(perform: onDisappear)
    }
}

private struct CameraStateEvents: ViewModifier {
    let capturedImage: UIImage?
    let permissionStatus: AVAuthorizationStatus
    let scenePhase: ScenePhase
    let onCapturedImage: (UIImage?) -> Void
    let onPermission: (AVAuthorizationStatus) -> Void
    let onScenePhase: (ScenePhase) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: capturedImage) { _, image in onCapturedImage(image) }
            .onChange(of: permissionStatus) { _, status in onPermission(status) }
            .onChange(of: scenePhase) { _, phase in onScenePhase(phase) }
    }
}

private struct CameraCalendarEvents: ViewModifier {
    let onRefresh: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                onRefresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                onRefresh()
            }
    }
}

private struct DualCameraPreparingSurface: View {
    let showProgress: Bool

    var body: some View {
        ZStack {
            Color(red: 18 / 255, green: 22 / 255, blue: 24 / 255)
                .ignoresSafeArea()

            LinearGradient(
                colors: [.white.opacity(0.035), .clear, .black.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if showProgress {
                ProgressView()
                    .tint(.white.opacity(0.82))
                    .scaleEffect(0.82)
                    .accessibilityLabel("カメラを準備しています")
            }
        }
        .allowsHitTesting(false)
    }
}

private struct DualCameraLightControl: View {
    let level: Double
    let isExpanded: Bool
    let isEnabled: Bool
    let reduceMotion: Bool
    let onTap: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onSliderChanged: (Double) -> Void
    let onSliderEnded: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onTap) {
                Image(systemName: "sun.max")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.94 : 0.48))
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.24), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .highPriorityGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { onDragChanged($0.translation) }
                    .onEnded { _ in onDragEnded() }
            )
            .accessibilityLabel("明るさを調整")
            .accessibilityValue("\(Int(level.rounded()))パーセント")
            .accessibilityAdjustableAction { direction in
                guard isEnabled else { return }
                switch direction {
                case .increment: onSliderChanged(min(100, level + 5))
                case .decrement: onSliderChanged(max(0, level - 5))
                @unknown default: return
                }
                onSliderEnded()
            }

            if isExpanded {
                VerticalLightSlider(
                    level: level,
                    onChanged: onSliderChanged,
                    onEnded: onSliderEnded
                )
                .transition(
                    reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
                )
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isExpanded)
        .allowsHitTesting(isEnabled)
    }
}

private struct VerticalLightSlider: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let level: Double
    let onChanged: (Double) -> Void
    let onEnded: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let travel = max(1, proxy.size.height - 30)
            let fraction = min(1, max(0, level / 100))
            let handleY = 15 + CGFloat(1 - fraction) * travel

            ZStack(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(0.42))
                    .frame(width: 2, height: travel)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                Capsule()
                    .fill(.white.opacity(0.76))
                    .frame(width: 2, height: max(0, proxy.size.height - 15 - handleY))
                    .position(
                        x: proxy.size.width / 2,
                        y: handleY + max(0, proxy.size.height - 15 - handleY) / 2
                    )

                Capsule()
                    .fill(.white.opacity(0.55))
                    .frame(width: 8, height: 1)
                    .position(x: proxy.size.width / 2, y: 15 + travel * 0.5)

                Text("100")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.54))
                    .position(x: 8, y: 10)

                Text("0")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.54))
                    .position(x: 8, y: proxy.size.height - 10)

                Circle()
                    .fill(Color.white.opacity(0.94))
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
                    .position(
                        x: proxy.size.width / 2,
                        y: handleY
                    )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let percentage = (1 - Double((value.location.y - 15) / travel)) * 100
                        onChanged(min(100, max(0, percentage)))
                    }
                    .onEnded { _ in onEnded() }
            )
        }
        .frame(width: 44, height: verticalSizeClass == .compact ? 156 : 180)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .background(.black.opacity(0.20), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("明るさ")
        .accessibilityValue("\(Int(level.rounded()))パーセント")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChanged(min(100, level + 5))
            case .decrement: onChanged(max(0, level - 5))
            @unknown default: return
            }
            onEnded()
        }
    }
}

private struct LightPercentageHUD: View {
    let level: Double

    var body: some View {
        VStack(spacing: 2) {
            Text("LIGHT")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.68))
            Text("\(Int(level.rounded()))%")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }
}

private struct DualCameraReviewView: View {
    let result: DualCameraCaptureResult
    let isSaving: Bool
    let onClose: () -> Void
    let onRetake: () -> Void
    let onSave: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { proxy in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: result.backImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .accessibilityLabel("その時に見ていた景色")

                    LinearGradient(colors: [.black.opacity(0.42), .clear, .black.opacity(0.58)], startPoint: .top, endPoint: .bottom)
                        .allowsHitTesting(false)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("YOU")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.9))
                        Image(uiImage: result.frontImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width * 0.32, height: proxy.size.width * 0.40)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.72), lineWidth: 1))
                            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                            .accessibilityLabel("その時の自分")
                    }
                    .padding(.top, 86)
                    .padding(.trailing, 18)
                }
            }

            VStack(spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(LockUCameraControlStyle())
                    .disabled(isSaving)
                    .accessibilityLabel("Dual Memoryを閉じる")
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                Text("WHAT YOU SAW")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.84))
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)

                Spacer()

                VStack(spacing: 12) {
                    Button("撮り直す", action: onRetake)
                        .buttonStyle(LockUSecondaryButtonStyle())
                        .disabled(isSaving)
                    Button(action: onSave) {
                        if isSaving {
                            HStack(spacing: 8) { ProgressView(); Text("保存しています…") }
                        } else {
                            Text("ロッカーに残す")
                        }
                    }
                    .buttonStyle(LockUPrimaryButtonStyle())
                    .disabled(isSaving)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.68)], startPoint: .top, endPoint: .bottom))
            }
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
