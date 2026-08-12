import Combine
import SwiftUI
import UIKit

enum LockUTab: Hashable {
    case locker, book, camera, peek
}

enum LockerDoorState: Equatable {
    case closed
    case opening
    case open
    case closing

    var isOpenOrOpening: Bool {
        self == .open || self == .opening
    }

    var acceptsInput: Bool {
        self == .closed || self == .open
    }
}

@MainActor
final class LockUAppModel: ObservableObject {
    @Published var selectedTab: LockUTab = .locker
    @Published var presentedError: String?
    @Published var isReady = false
    @Published var lockerDoorState: LockerDoorState = .closed
    @Published var isCameraPresented = false
    @Published var selectedCapturedImage: UIImage?
    @Published var cameraPermissionDenied = false
    @Published var peekMemory: MemoryRecord?
    @Published private(set) var bootState: AppBootState = .launching
    @Published private(set) var shouldShowFirstLocker = false
    @Published private(set) var memoryVariationPlan: LockerMemoryVariationPlan?

    let memoryRepository: MemoryRepository
    let decorationRepository: DecorationRepository
    let settingsRepository: LockerSettingsRepository
    let backgroundRepository: BackgroundRepository
    let revisitCoordinator: RevisitCoordinator
    let reflectionRepository: MemoryReflectionRepository
    let demoClock: LockUDemoClock
    let storageMode: StorageMode
    private let dependencies: LockUDependencyContainer
    private let onboardingDefaults = UserDefaults.standard
    private let onboardingCompletionKey = "locku.first-locker.completed.v1"

    init() {
        let dependencies = LockUDependencyContainer()
        self.dependencies = dependencies
        storageMode = dependencies.storageMode
        memoryRepository = dependencies.memoryRepository
        decorationRepository = dependencies.decorationRepository
        settingsRepository = dependencies.settingsRepository
        backgroundRepository = dependencies.backgroundRepository
        revisitCoordinator = RevisitCoordinator()
        reflectionRepository = dependencies.reflectionRepository
        demoClock = LockUDemoClock()
        Task { @MainActor [weak self] in
            await self?.boot()
        }
    }

    private func boot() async {
        let wasPreviouslyMigrated = onboardingDefaults.bool(forKey: "locku.migration.v2.completed")
        let coordinator = LockUBootCoordinator(dependencies: dependencies)
        let essential = await coordinator.performEssentialBoot { bootState = $0 }
        if storageMode == .recoveryTemporary { presentedError = "一時復旧モードで起動しました。新しいデータは永続保存されません。" }
        else if let error = essential.error { presentedError = error.localizedDescription }

        updateOnboardingState(
            hasExistingMigration: wasPreviouslyMigrated,
            migrationDecisionFinalized: wasPreviouslyMigrated
        )
        refreshTimeDependentState()
        isReady = true

        // Give SwiftUI an opportunity to present Locker Home before deferred disk work begins.
        await Task.yield()
        let deferred = await coordinator.performDeferredBoot { bootState = $0 }
        if presentedError == nil, let error = deferred.error {
            presentedError = error.localizedDescription
        }
        updateOnboardingState(
            hasExistingMigration: wasPreviouslyMigrated || deferred.didMigrate,
            migrationDecisionFinalized: true
        )
        refreshTimeDependentState()
    }

    private func updateOnboardingState(
        hasExistingMigration: Bool,
        migrationDecisionFinalized: Bool
    ) {
        let hasExistingData = !memoryRepository.memories.isEmpty
            || !decorationRepository.decorations.isEmpty
            || settingsRepository.hasStoredData
            || backgroundRepository.image != nil
            || hasExistingMigration
        if hasExistingData { onboardingDefaults.set(true, forKey: onboardingCompletionKey) }
        let onboardingCompleted = onboardingDefaults.bool(forKey: onboardingCompletionKey)
        shouldShowFirstLocker = migrationDecisionFinalized && !hasExistingData && !onboardingCompleted
    }

    func report(_ error: Error) {
        presentedError = error.localizedDescription
    }

    func completeFirstLocker() {
        onboardingDefaults.set(true, forKey: onboardingCompletionKey)
        shouldShowFirstLocker = false
    }

    func refreshTimeDependentState() {
        let currentDate = demoClock.now
        revisitCoordinator.refresh(memories: memoryRepository.memories, now: currentDate)
        let appearance = settingsRepository.settings.appearance
        memoryVariationPlan = LockerMemoryVariationService().plan(
            for: currentDate,
            memories: memoryRepository.memories,
            featuredVideoMemoryID: appearance.featuredVideoMemoryID,
            enabled: appearance.dailyVariationEnabled
        )
    }

    #if DEBUG
    func selectDemoPreset(_ preset: LockUDemoTimePreset) {
        demoClock.select(preset, memories: memoryRepository.memories)
        refreshTimeDependentState()
    }
    #endif
}

struct LockURootView: View {
    @StateObject private var model = LockUAppModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if model.selectedTab == .locker {
                    LockerSceneBackground()
                } else if model.selectedTab != .camera {
                    SkyBackground()
                }
            }
            .transition(.opacity)
            .zIndex(LockUSceneTokens.Layer.environment)

            Group {
                if !model.isReady {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                } else if model.shouldShowFirstLocker {
                    FirstLockerOnboardingView()
                } else {
                    content
                }
            }
                .id(model.selectedTab)
                .transition(.opacity.combined(with: .scale(scale: 0.992)))
                .zIndex(LockUSceneTokens.Layer.physical)

            if model.isReady && model.selectedTab != .camera && !model.shouldShowFirstLocker {
                LockUBottomBar(selection: $model.selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(LockUSceneTokens.Layer.interface)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.selectedTab)
        .onChange(of: model.selectedTab) { _, tab in
            if tab != .peek { model.peekMemory = nil }
        }
        .environmentObject(model)
        .environmentObject(model.memoryRepository)
        .environmentObject(model.decorationRepository)
        .environmentObject(model.settingsRepository)
        .environmentObject(model.backgroundRepository)
        .environmentObject(model.revisitCoordinator)
        .environmentObject(model.reflectionRepository)
        .environmentObject(model.demoClock)
        .alert(
            "LockU",
            isPresented: Binding(
                get: { model.presentedError != nil },
                set: { if !$0 { model.presentedError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { model.presentedError = nil }
        } message: {
            Text(model.presentedError ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.selectedTab {
        case .locker:
            HallwayView()
                .frame(maxWidth: LockUDesign.contentMaxWidth)
                .padding(.bottom, LockUDesign.bottomBarHeight + 16)
        case .book:
            MemoryBookshelfView()
                .frame(maxWidth: LockUDesign.contentMaxWidth)
                .padding(.bottom, LockUDesign.bottomBarHeight + LockUDesign.Spacing.medium)
        case .camera:
            CameraCaptureView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .peek:
            PeekView()
                .frame(maxWidth: LockUDesign.contentMaxWidth)
                .padding(.bottom, LockUDesign.bottomBarHeight + LockUDesign.Spacing.medium)
        }
    }
}

#Preview {
    LockURootView()
}
