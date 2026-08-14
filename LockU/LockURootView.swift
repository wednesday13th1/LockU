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

enum MemoryPlacementRitualPhase: Equatable {
    case preparing, paperizing, moving, settling, completed
}

struct MemoryPlacementRitualDestination: Equatable {
    let frame: CGRect
    let rotationDegrees: Double
    let frameStyle: LockerFrameStyle
}

struct MemoryPlacementRitualSession: Identifiable {
    let id: UUID
    let memoryID: UUID
    let image: UIImage
    let moodEmoji: String?
    let memoryNote: String?
    let createdAt: Date
    var phase: MemoryPlacementRitualPhase
    var destination: MemoryPlacementRitualDestination?
}

@MainActor
final class LockUAppModel: ObservableObject {
    @Published var selectedTab: LockUTab = .locker
    @Published var presentedError: String?
    @Published var isReady = false
    @Published var lockerDoorState: LockerDoorState = .closed
    @Published var isCameraPresented = false
    @Published var selectedCapturedImage: UIImage?
    @Published private(set) var placementRitual: MemoryPlacementRitualSession?
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
    let lockerCanvasRepository: LockerCanvasRepository
    let demoClock: LockUDemoClock
    let storageMode: StorageMode
    private let dependencies: LockUDependencyContainer
    private let onboardingDefaults = UserDefaults.standard
    private let onboardingCompletionKey = "locku.first-locker.completed.v1"
    private var deferredBootTask: Task<Void, Never>?
    private var deferredBootGeneration = 0
    private var didLogLockerFirstRender = false

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
        lockerCanvasRepository = dependencies.lockerCanvasRepository
        demoClock = LockUDemoClock()
        launchLog("APP_LAUNCH")
        Task { @MainActor [weak self] in
            // Let the initial background and controls render before metadata I/O begins.
            await Task.yield()
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
        launchLog("CORE_READY")

        scheduleDeferredBoot()
    }

    private func scheduleDeferredBoot() {
        guard deferredBootTask == nil, !isCameraPresented else { return }
        deferredBootGeneration &+= 1
        let generation = deferredBootGeneration
        deferredBootTask = Task(priority: .utility) { @MainActor [weak self] in
            guard let self else { return }
            await Task.yield()
            guard !Task.isCancelled, !isCameraPresented else {
                if generation == deferredBootGeneration { deferredBootTask = nil }
                return
            }

            let wasPreviouslyMigrated = onboardingDefaults.bool(forKey: "locku.migration.v2.completed")
            let coordinator = LockUBootCoordinator(dependencies: dependencies)
            let deferred = await coordinator.performDeferredBoot { bootState = $0 }
            if generation == deferredBootGeneration { deferredBootTask = nil }
            guard !Task.isCancelled, generation == deferredBootGeneration else { return }
            if presentedError == nil, let error = deferred.error {
                presentedError = error.localizedDescription
            }
            updateOnboardingState(
                hasExistingMigration: wasPreviouslyMigrated || deferred.didMigrate,
                migrationDecisionFinalized: true
            )
            refreshTimeDependentState()
            launchLog("DEFERRED_READY")
        }
    }

    func setCameraPresented(_ presented: Bool) {
        guard isCameraPresented != presented else { return }
        isCameraPresented = presented
        if presented {
            launchLog("CAMERA_REQUESTED")
            deferredBootGeneration &+= 1
            deferredBootTask?.cancel()
            deferredBootTask = nil
            memoryRepository.releaseRebuildableDisplayResources()
            lockerCanvasRepository.releaseRebuildableDisplayResources()
        } else {
            scheduleDeferredBoot()
        }
    }

    func markLockerFirstRender() {
        guard !didLogLockerFirstRender else { return }
        didLogLockerFirstRender = true
        launchLog("LOCKER_FIRST_RENDER")
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

    func beginPlacementRitual(memory: MemoryRecord, displayImage: UIImage) {
        guard placementRitual == nil else { return }
        placementRitual = MemoryPlacementRitualSession(
            id: UUID(), memoryID: memory.id,
            image: displayImage.lockUDownsampled(maxDimension: 640),
            moodEmoji: memory.moodEmoji, memoryNote: memory.memoryNote,
            createdAt: memory.createdAt, phase: .preparing, destination: nil
        )
    }

    func registerPlacementRitualDestination(memoryID: UUID, destination: MemoryPlacementRitualDestination) {
        guard var ritual = placementRitual, ritual.memoryID == memoryID, ritual.destination == nil else { return }
        ritual.destination = destination
        placementRitual = ritual
    }

    func setPlacementRitualPhase(_ phase: MemoryPlacementRitualPhase, sessionID: UUID) {
        guard var ritual = placementRitual, ritual.id == sessionID else { return }
        ritual.phase = phase
        placementRitual = ritual
    }

    func completePlacementRitual(sessionID: UUID) {
        guard placementRitual?.id == sessionID else { return }
        placementRitual = nil
        selectedCapturedImage = nil
    }

    func isPlacementRitualActive(for memoryID: UUID) -> Bool {
        guard let ritual = placementRitual else { return false }
        return ritual.memoryID == memoryID && ritual.phase != .completed
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

    private func launchLog(_ event: String) {
        #if DEBUG
        let milliseconds = Int(Date().timeIntervalSince1970 * 1_000)
        print("[LockU][Launch][\(event)] t=\(milliseconds) boot=\(bootState) camera=\(isCameraPresented)")
        #endif
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
                if model.selectedTab == .camera && !model.shouldShowFirstLocker {
                    content
                } else if !model.isReady {
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

            if model.selectedTab != .camera && !model.shouldShowFirstLocker {
                if model.placementRitual == nil {
                    LockUBottomBar(selection: $model.selectedTab)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(LockUSceneTokens.Layer.interface)
                }
            }

            if model.placementRitual != nil {
                MemoryPlacementRitualOverlay()
                    .zIndex(LockUSceneTokens.Layer.interface + 20)
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
        .environmentObject(model.lockerCanvasRepository)
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
                .padding(.bottom, LockUDesign.bottomBarHeight + 8)
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
