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
    @Published private(set) var bootState: AppBootState = .launching

    let memoryRepository: MemoryRepository
    let decorationRepository: DecorationRepository
    let settingsRepository: LockerSettingsRepository
    let backgroundRepository: BackgroundRepository
    let storageMode: StorageMode
    private let dependencies: LockUDependencyContainer

    init() {
        let dependencies = LockUDependencyContainer()
        self.dependencies = dependencies
        storageMode = dependencies.storageMode
        memoryRepository = dependencies.memoryRepository
        decorationRepository = dependencies.decorationRepository
        settingsRepository = dependencies.settingsRepository
        backgroundRepository = dependencies.backgroundRepository
        load()
    }

    private func load() {
        let (_, error) = LockUBootCoordinator(dependencies: dependencies).boot { bootState = $0 }
        if storageMode == .recoveryTemporary { presentedError = "一時復旧モードで起動しました。新しいデータは永続保存されません。" }
        else if let error { presentedError = error.localizedDescription }
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
            Group {
                if model.selectedTab == .locker {
                    LockerSceneBackground()
                } else if model.selectedTab != .camera {
                    SkyBackground()
                }
            }
            .transition(.opacity)
            .zIndex(LockUSceneTokens.Layer.environment)

            content
                .id(model.selectedTab)
                .transition(.opacity.combined(with: .scale(scale: 0.992)))
                .zIndex(LockUSceneTokens.Layer.physical)

            if model.selectedTab != .camera {
                LockUBottomBar(selection: $model.selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(LockUSceneTokens.Layer.interface)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.selectedTab)
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
