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

    let memoryRepository: MemoryRepository
    let decorationRepository: DecorationRepository
    let settingsRepository: LockerSettingsRepository
    let backgroundRepository: BackgroundRepository

    init() {
        do {
            let paths = try LockUPaths()
            memoryRepository = MemoryRepository(paths: paths)
            decorationRepository = DecorationRepository(paths: paths)
            settingsRepository = LockerSettingsRepository(paths: paths)
            backgroundRepository = BackgroundRepository(paths: paths)
        } catch {
            let fallback = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("LockU-Recovery", isDirectory: true)
            try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
            let paths = LockUPaths(recoveryRoot: fallback)
            memoryRepository = MemoryRepository(paths: paths)
            decorationRepository = DecorationRepository(paths: paths)
            settingsRepository = LockerSettingsRepository(paths: paths)
            backgroundRepository = BackgroundRepository(paths: paths)
            presentedError = error.localizedDescription
        }
        load()
    }

    private func load() {
        do {
            try settingsRepository.reload()
            try memoryRepository.reload()
            try decorationRepository.reload()
            backgroundRepository.reload()
            let migration = LegacyMigrationService(
                memories: memoryRepository,
                decorations: decorationRepository,
                settings: settingsRepository,
                backgrounds: backgroundRepository
            )
            try migration.migrateIfNeeded()
            try memoryRepository.reload()
            try decorationRepository.reload()
            backgroundRepository.reload()
        } catch {
            presentedError = error.localizedDescription
        }
        isReady = true
    }

    func report(_ error: Error) {
        presentedError = error.localizedDescription
    }
}

struct LockURootView: View {
    @StateObject private var model = LockUAppModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            if model.selectedTab == .locker {
                LockerSceneBackground()
            } else {
                SkyBackground()
            }
            content

            if model.selectedTab != .camera {
                LockUBottomBar(selection: $model.selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environmentObject(model)
        .environmentObject(model.memoryRepository)
        .environmentObject(model.decorationRepository)
        .environmentObject(model.settingsRepository)
        .environmentObject(model.backgroundRepository)
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
                .padding(.bottom, LockUDesign.bottomBarHeight + LockUDesign.Spacing.medium)
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
