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
    @State private var isChangingCameraMode = false
    @State private var selectedMoodEmoji: MemoryMoodEmoji?
    @State private var memoryNote = ""
    @State private var isSavingDualMemory = false
    @State private var lightLevel: Double = 0.5
    @State private var isAdjustingLight = false
    @State private var showLightHUD = false
    @State private var hideLightHUDTask: Task<Void, Never>?
    @State private var secondaryPreviewCorner: DualCameraPiPCorner = .topTrailing
    @State private var secondaryPreviewDragOffset: CGSize = .zero
    @State private var isDraggingSecondaryPreview = false
    @State private var secondaryPreviewSnapToken = 0
    @State private var dualPresentation: DualCameraPresentation = .backMain
    @State private var isSwappingDualPresentation = false
    @State private var dualPresentationSwapToken = 0
    @State private var swapCompletionTask: Task<Void, Never>?

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
            selectedMoodEmoji: $selectedMoodEmoji,
            memoryNote: $memoryNote,
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
            selectedMoodEmoji: $selectedMoodEmoji,
            memoryNote: $memoryNote,
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
        camera.setCameraScreenActive(false)
        camera.setApplicationActive(false)
        camera.stopSession()
        editor.clear()
        camera.clearDualCapture()
        clearMemoryExpression()
        hideLightHUDTask?.cancel()
        hideLightHUDTask = nil
        isAdjustingLight = false
        showLightHUD = false
        secondaryPreviewDragOffset = .zero
        isDraggingSecondaryPreview = false
        swapCompletionTask?.cancel()
        swapCompletionTask = nil
        isSwappingDualPresentation = false
        isChangingCameraMode = false
        appModel.setCameraPresented(false)
    }

    private func handlePermissionChange(_ status: AVAuthorizationStatus) {
        appModel.cameraPermissionDenied = status == .denied || status == .restricted
    }

    private func handleCalendarRefresh() {
        refreshDailyFilm(allowReveal: false)
    }

    private func handleCapturedImage(_ image: UIImage?) {
        guard let image else { return }
        clearMemoryExpression()
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
            isChangingCameraMode = false
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
                DualCameraPreviewView(
                    manager: camera,
                    presentation: dualPresentation,
                    pipCorner: secondaryPreviewCorner,
                    pipDragOffset: secondaryPreviewDragOffset,
                    isDraggingPiP: isDraggingSecondaryPreview,
                    pipSnapToken: secondaryPreviewSnapToken,
                    presentationSwapToken: dualPresentationSwapToken
                )
                    .ignoresSafeArea()
                    .opacity(dualPreviewIsVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.16), value: dualPreviewIsVisible)
                    .accessibilityLabel("見ている景色と、その時の自分のカメラプレビュー")
            } else {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea(edges: .top)
                    .dailyFilmPreview(dailyFilm)
            }


            if captureExperience == .dual {
                CameraLightEffectView(level: lightLevel)
                    .zIndex(1)
            }

            if captureExperience == .dual {
                DualCameraPiPDragSurface(
                    corner: secondaryPreviewCorner,
                    dragOffset: secondaryPreviewDragOffset,
                    onDragChanged: handleSecondaryPreviewDragChanged,
                    onDragEnded: handleSecondaryPreviewDragEnded
                )
                .zIndex(6)
            }

            if captureExperience == .dual {
                CameraLightHUD(level: lightLevel)
                    .offset(y: 58)
                    .opacity(showLightHUD ? 1 : 0)
                    .scaleEffect(reduceMotion ? 1 : (showLightHUD ? 1 : 0.96))
                    .zIndex(30)
            }

            if captureExperience == .dual {
                DualCameraLightControlLayout(
                    level: $lightLevel,
                    onEditingChanged: handleLightEditingChanged
                )
                .zIndex(10)
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

            VStack {
                topControls
                Spacer()
                bottomControls
            }
            .zIndex(20)

            if showFilmReveal && captureExperience == .single {
                filmReveal
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            Color.white
                .opacity(flashOverlay ? 0.58 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.16), value: flashOverlay)
                .zIndex(40)
        }
        .onChange(of: camera.dualCameraUXState) { _, state in
            if state == .ready {
                camera.markDualPreviewVisible()
                camera.setDualLightLevel(lightLevel, force: true)
            }
        }
        .onChange(of: lightLevel) { _, level in
            guard captureExperience == .dual else { return }
            camera.setDualLightLevel(level)
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

                if captureExperience == .dual {
                    HStack {
                        Spacer()
                        cameraCircleButton(icon: "camera.rotate") {
                            swapDualPresentation()
                        }
                        .rotationEffect(.degrees(dualPresentation == .frontMain ? 160 : 0))
                        .animation(.easeOut(duration: 0.22), value: dualPresentation)
                        .disabled(isSwappingDualPresentation || !dualPreviewIsVisible)
                        .accessibilityLabel("Swap main camera")
                    }
                    .padding(.horizontal, 24)
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
                    .disabled(!camera.canCapture || isSwappingDualPresentation)
                    .opacity(camera.canCapture && !isSwappingDualPresentation ? 1 : 0.5)
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

    private func handleLightEditingChanged(_ editing: Bool) {
        hideLightHUDTask?.cancel()
        hideLightHUDTask = nil

        if editing {
            isAdjustingLight = true
#if DEBUG
            print("[CameraUI][LIGHT_DRAG_BEGIN]")
#endif
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                showLightHUD = true
            }
            return
        }

        isAdjustingLight = false
        camera.setDualLightLevel(lightLevel, force: true)
#if DEBUG
        print("[CameraUI][LIGHT_DRAG_END] value=\(Int((lightLevel * 100).rounded()))")
#endif
        hideLightHUDTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(450))
            } catch {
                return
            }
            guard !Task.isCancelled, !isAdjustingLight else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                showLightHUD = false
            }
            hideLightHUDTask = nil
        }
    }

    private func handleSecondaryPreviewDragChanged(_ translation: CGSize) {
        if !isDraggingSecondaryPreview {
            isDraggingSecondaryPreview = true
#if DEBUG
            print("[CameraUI][PIP_DRAG_BEGIN]")
#endif
        }
        secondaryPreviewDragOffset = translation
    }

    private func handleSecondaryPreviewDragEnded(_ translation: CGSize, layout: DualCameraOverlayLayout) {
        let sourceCorner = secondaryPreviewCorner
        let sourceFrame = layout.pipFrame(for: sourceCorner)
            .offsetBy(dx: translation.width, dy: translation.height)
        let targetCorner = layout.nearestValidPiPCorner(from: CGPoint(x: sourceFrame.midX, y: sourceFrame.midY))

        secondaryPreviewCorner = targetCorner
        secondaryPreviewDragOffset = .zero
        isDraggingSecondaryPreview = false
        secondaryPreviewSnapToken &+= 1

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#if DEBUG
        print("[CameraUI][PIP_SNAP] from=\(sourceCorner.rawValue) to=\(targetCorner.rawValue)")
        print("[CameraUI][PIP_DRAG_END]")
#endif
    }

    private func swapDualPresentation() {
        guard !isSwappingDualPresentation, dualPreviewIsVisible else { return }
        swapCompletionTask?.cancel()
        isSwappingDualPresentation = true
        let source = dualPresentation
#if DEBUG
        print("[CameraUI][SWAP_BEGIN] from=\(source.rawValue)")
#endif
        dualPresentation = source == .backMain ? .frontMain : .backMain
        dualPresentationSwapToken &+= 1

        swapCompletionTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(240))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            isSwappingDualPresentation = false
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
#if DEBUG
            print("[CameraUI][SWAP_END] to=\(dualPresentation.rawValue)")
#endif
            swapCompletionTask = nil
        }
    }

    private var captureModeSelector: some View {
        HStack(spacing: 26) {
            modeButton("PHOTO", experience: .single)
            modeButton("DUAL", experience: .dual)
        }
        .disabled(camera.isCapturing || isChangingCameraMode)
        .accessibilityElement(children: .contain)
    }

    private func modeButton(_ title: String, experience: LockUCaptureExperience) -> some View {
        Button {
            guard captureExperience != experience, !isChangingCameraMode else { return }
            isChangingCameraMode = true
            if reduceMotion { captureExperience = experience }
            else { withAnimation(.easeInOut(duration: 0.24)) { captureExperience = experience } }
            if experience == .dual {
                camera.startDualSession { started in
                    if !started, camera.dualCameraUXState == .unsupported {
                        if reduceMotion { captureExperience = .single }
                        else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                captureExperience = .single
                            }
                        }
                    }
                    isChangingCameraMode = false
                }
            }
            else {
                camera.clearDualCapture()
                camera.useSingleCamera {
                    isChangingCameraMode = false
                }
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
        camera.startDualSession()
    }

    private func retakeDual() {
        guard !isSavingDualMemory else { return }
        clearMemoryExpression()
        camera.retakeDualCapture()
    }

    private func closeDualReview() {
        guard !isSavingDualMemory else { return }
        camera.clearDualCapture()
        clearMemoryExpression()
        appModel.selectedTab = .locker
    }

    private func saveDual(result: DualCameraCaptureResult) {
        guard !isSavingDualMemory else { return }
        isSavingDualMemory = true
        do {
            let memory = try memoryRepository.saveDualCameraMemory(
                frontImage: result.frontImage,
                backImage: result.backImage,
                createdAt: result.requestedAt,
                memoryNote: memoryNote,
                moodEmoji: selectedMoodEmoji?.rawValue
            )
            camera.clearDualCapture()
            clearMemoryExpression()
            isSavingDualMemory = false
            let ritualImage = memoryRepository.image(
                for: memory,
                purpose: .detail,
                targetPointSize: CGSize(width: 320, height: 320)
            ) ?? result.backImage.lockUDownsampled(maxDimension: 640)
            appModel.beginPlacementRitual(memory: memory, displayImage: ritualImage)
            appModel.lockerDoorState = .open
            appModel.selectedTab = .locker
        } catch {
            isSavingDualMemory = false
            appModel.report(error)
        }
    }

    private var alreadyCapturedView: some View {
        VStack(spacing: 18) {
            if let memory = memoryRepository.memories.first,
               let image = memoryRepository.image(
                    for: memory,
                    purpose: .detail,
                    targetPointSize: CGSize(width: 128, height: 145)
               ) {
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
            Text("今日も残った。")
                .font(LockUDesign.Typography.sectionTitle)
                .foregroundStyle(LockUDesign.Color.schoolNavy)
            Button("ロッカーへ戻る") {
                appModel.lockerDoorState = .open
                appModel.selectedTab = .locker
            }
            .buttonStyle(LockUPrimaryButtonStyle())
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
        clearMemoryExpression()
        reviewMode = .photoLibrary
        captureHasDailyFilm = false
        editor.reset(with: image)
    }

    private func retake() {
        editor.clear()
        camera.capturedImage = nil
        captureHasDailyFilm = false
        clearMemoryExpression()
        camera.startSession()
    }

    private func closeEditor() {
        editor.clear()
        camera.capturedImage = nil
        clearMemoryExpression()
        appModel.selectedTab = .locker
    }

    private func save() {
        guard let image = editor.imageToSave, !isSaving else { return }
        let imageStyle = editor.selectedStyle
        isSaving = true
        do {
            let memory = try memoryRepository.saveImage(
                image,
                createdAt: .now,
                filterID: nil,
                weather: nil,
                captureMode: reviewMode,
                imageStyle: imageStyle,
                dailyFilm: captureHasDailyFilm && reviewMode == .camera ? dailyFilm : nil,
                memoryNote: memoryNote,
                moodEmoji: selectedMoodEmoji?.rawValue
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
            clearMemoryExpression()
            isSaving = false
            let ritualImage = image.lockUDownsampled(maxDimension: 640)
            appModel.beginPlacementRitual(memory: memory, displayImage: ritualImage)
            appModel.lockerDoorState = .open
            appModel.selectedTab = .locker
        } catch {
            isSaving = false
            appModel.report(error)
        }
    }

    private func clearMemoryExpression() {
        selectedMoodEmoji = nil
        memoryNote = ""
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

private struct CameraLightEffectView: View {
    let level: Double

    private var normalizedLevel: Double {
        guard level.isFinite else { return 0.5 }
        return min(1, max(0, level))
    }

    private var baseLift: Double {
        0.035 * pow(normalizedLevel, 1.2)
    }

    private var softClear: Double {
        let arrival = smoothStep(from: 0.24, to: 0.68, value: normalizedLevel)
        let flashTransition = smoothStep(from: 0.70, to: 1, value: normalizedLevel)
        return arrival * (1 - (flashTransition * 0.28))
    }

    private var digicamFlash: Double {
        smoothStep(from: 0.70, to: 1, value: normalizedLevel)
    }

    private func smoothStep(from lowerBound: Double, to upperBound: Double, value: Double) -> Double {
        let progress = min(1, max(0, (value - lowerBound) / (upperBound - lowerBound)))
        return progress * progress * (3 - (2 * progress))
    }

    var body: some View {
        ZStack {
            // A quiet daylight lift that preserves the original preview at low values.
            LinearGradient(
                colors: [
                    .white.opacity(baseLift + (softClear * 0.018)),
                    .white.opacity(baseLift * 0.72),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Clear blue-white air in the middle range, kept below visible color-cast levels.
            Color(red: 0.86, green: 0.94, blue: 1)
                .opacity((softClear * 0.014) + (digicamFlash * 0.010))
                .blendMode(.softLight)

            // A broad highlight reads like compact-camera light without becoming a spotlight.
            RadialGradient(
                colors: [
                    .white.opacity((softClear * 0.026) + (digicamFlash * 0.034)),
                    .white.opacity(digicamFlash * 0.012),
                    .clear
                ],
                center: UnitPoint(x: 0.34, y: 0.30),
                startRadius: 8,
                endRadius: 430
            )
            .blendMode(.screen)

            // High-range flash lift stays directional so blacks are not uniformly washed gray.
            LinearGradient(
                colors: [
                    .white.opacity(digicamFlash * 0.036),
                    Color(red: 0.91, green: 0.96, blue: 1).opacity(digicamFlash * 0.018),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.screen)

            LinearGradient(
                colors: [.clear, .black.opacity(digicamFlash * 0.010)],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.softLight)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct DualCameraLightControlLayout: View {
    @Binding var level: Double
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        GeometryReader { proxy in
            let layout = DualCameraOverlayLayout(
                bounds: CGRect(origin: .zero, size: proxy.size),
                safeAreaTop: proxy.safeAreaInsets.top,
                safeAreaBottom: proxy.safeAreaInsets.bottom
            )

            VStack(spacing: 0) {
                Color.clear
                    .frame(height: layout.lightControlTop)
                    .allowsHitTesting(false)

                VerticalCameraLightControl(
                    level: $level,
                    trackHeight: layout.lightTrackHeight,
                    onEditingChanged: onEditingChanged
                )

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 16)
        }
    }
}

private struct DualCameraPiPDragSurface: View {
    let corner: DualCameraPiPCorner
    let dragOffset: CGSize
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: (CGSize, DualCameraOverlayLayout) -> Void

    var body: some View {
        GeometryReader { proxy in
            let layout = DualCameraOverlayLayout(
                bounds: CGRect(origin: .zero, size: proxy.size),
                safeAreaTop: proxy.safeAreaInsets.top,
                safeAreaBottom: proxy.safeAreaInsets.bottom
            )
            let baseFrame = layout.pipFrame(for: corner)

            Color.clear
                .frame(width: baseFrame.width, height: baseFrame.height)
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .offset(
                    x: baseFrame.minX + dragOffset.width,
                    y: baseFrame.minY + dragOffset.height
                )
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { onDragChanged($0.translation) }
                        .onEnded { onDragEnded($0.translation, layout) }
                )
                .accessibilityLabel("Move secondary camera preview")
                .accessibilityHint("Drag and release to snap to a safe corner")
        }
        .allowsHitTesting(true)
    }
}

private struct VerticalCameraLightControl: View {
    @Binding var level: Double
    let trackHeight: CGFloat
    let onEditingChanged: (Bool) -> Void
    @State private var isDragging = false

    private var percentage: Int {
        Int((min(1, max(0, level)) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("LIGHT")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
            Text("\(percentage)%")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .monospacedDigit()

            VerticalLightTrack(
                level: $level,
                isDragging: $isDragging,
                onEditingChanged: onEditingChanged
            )
            .frame(width: 44, height: trackHeight)

            Image(systemName: "sun.max.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(red: 1, green: 0.91, blue: 0.67))

            Capsule()
                .fill(.white.opacity(0.14))
                .frame(width: 34, height: 0.5)

            Button {
                level = 0.5
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                    Text("RESET")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(1.1)
                    Text("50%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                }
                .frame(width: 52, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset camera light")
            .accessibilityValue("50 percent")
        }
        .foregroundStyle(.white.opacity(0.92))
        .padding(.vertical, 12)
        .frame(width: 76)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
    }
}

private struct VerticalLightTrack: View {
    @Binding var level: Double
    @Binding var isDragging: Bool
    let onEditingChanged: (Bool) -> Void

    private var safeLevel: Double {
        guard level.isFinite else { return 0.5 }
        return min(1, max(0, level))
    }

    var body: some View {
        GeometryReader { proxy in
            let trackHeight = max(1, proxy.size.height - 30)
            let thumbY = 15 + CGFloat(1 - safeLevel) * trackHeight

            ZStack(alignment: .top) {
                Capsule()
                    .fill(.black.opacity(0.34))
                    .frame(width: 7, height: trackHeight)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                Capsule()
                    .fill(Color(red: 1, green: 0.92, blue: 0.70).opacity(0.88))
                    .frame(width: 7, height: CGFloat(safeLevel) * trackHeight)
                    .position(
                        x: proxy.size.width / 2,
                        y: thumbY + (CGFloat(safeLevel) * trackHeight / 2)
                    )

                Circle()
                    .fill(.white.opacity(0.96))
                    .frame(width: 30, height: 30)
                    .overlay(Circle().stroke(.black.opacity(0.12), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
                    .position(x: proxy.size.width / 2, y: thumbY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        let normalized = 1 - Double((gesture.location.y - 15) / trackHeight)
                        level = min(1, max(0, normalized))
                    }
                    .onEnded { _ in
                        guard isDragging else { return }
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Camera light")
        .accessibilityValue("\(Int((safeLevel * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: level = min(1, safeLevel + 0.05)
            case .decrement: level = max(0, safeLevel - 0.05)
            @unknown default: break
            }
        }
    }
}

private struct CameraLightHUD: View {
    let level: Double

    private var percentage: Int {
        let safeLevel = level.isFinite ? min(1, max(0, level)) : 0.5
        return Int((safeLevel * 100).rounded())
    }

    var body: some View {
        Text("\(percentage)%")
            .font(.system(size: 24, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.96))
            .frame(width: 92, height: 52)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .background(
                .black.opacity(0.16),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(.white.opacity(0.13), lineWidth: 0.5)
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct DualCameraReviewView: View {
    let result: DualCameraCaptureResult
    let isSaving: Bool
    @Binding var selectedMoodEmoji: MemoryMoodEmoji?
    @Binding var memoryNote: String
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

                ScrollView {
                    VStack(spacing: 12) {
                        MemoryExpressionEditor(
                            selectedMoodEmoji: $selectedMoodEmoji,
                            memoryNote: $memoryNote
                        )
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
                }
                .scrollDismissesKeyboard(.interactively)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.68)], startPoint: .top, endPoint: .bottom))
                .frame(maxHeight: 390)
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
        selectedMoodEmoji: .constant(nil),
        memoryNote: .constant(""),
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
        selectedMoodEmoji: .constant(nil),
        memoryNote: .constant(""),
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
        selectedMoodEmoji: .constant(nil),
        memoryNote: .constant(""),
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
