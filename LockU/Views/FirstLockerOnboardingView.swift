import Photos
import PhotosUI
import SwiftUI
import UIKit

struct SeedMemoryDraft: Identifiable {
    let id: UUID
    let image: UIImage
    let capturedAt: Date
    let assetIdentifier: String?
    let originalSelectionIndex: Int
}

@MainActor
private final class FirstLockerOnboardingViewModel: ObservableObject {
    @Published var selectedItems: [PhotosPickerItem] = []
    @Published private(set) var drafts: [SeedMemoryDraft] = []
    @Published private(set) var isLoadingSelection = false
    @Published private(set) var selectionWarning: String?
    @Published var selectedBackgroundStyle: LockerBackgroundStyle = .clearBlue
    @Published private(set) var isCreatingLocker = false
    @Published private(set) var creationError: String?
    @Published private(set) var requiresRecovery = false

    private var loadTask: Task<Void, Never>?
    private var selectionGeneration = UUID()

    var requiredMemoryCount: Int { LockerMemoryLayout.photoSlotCount }
    var canContinue: Bool { drafts.count == requiredMemoryCount && !isLoadingSelection }

    func createLocker(
        memoryRepository: MemoryRepository,
        settingsRepository: LockerSettingsRepository,
        now: Date = .now
    ) async -> Bool {
        guard !isCreatingLocker, !requiresRecovery, canContinue else { return false }
        isCreatingLocker = true
        creationError = nil
        defer { isCreatingLocker = false }

        let items = drafts.map { SeedMemoryImportItem(image: $0.image, capturedAt: $0.capturedAt) }
        var importedIDs = Set<UUID>()
        do {
            let imported = try await memoryRepository.importSeedMemories(items, importedAt: now)
            importedIDs = Set(imported.map(\.id))

            var updatedSettings = settingsRepository.settings
            updatedSettings.appearance.backgroundStyle = selectedBackgroundStyle
            do {
                try settingsRepository.update(updatedSettings)
            } catch let settingsError {
                do {
                    try memoryRepository.rollbackSeedImport(ids: importedIDs)
                } catch let rollbackError {
                    requiresRecovery = true
                    LockULog.error(.transaction, "First Locker settings save failed: \(settingsError.localizedDescription); seed rollback failed: \(rollbackError.localizedDescription)")
                    creationError = "ロッカーを作れませんでした。保存状態を確認する必要があります。アプリを再起動してください。"
                    return false
                }
                throw settingsError
            }
            return true
        } catch {
            LockULog.error(.transaction, "First Locker creation failed")
            creationError = "ロッカーを作れませんでした。写真と背景はまだ確定されていません。もう一度試してください。"
            return false
        }
    }

    func selectionDidChange() {
        loadTask?.cancel()
        let generation = UUID()
        selectionGeneration = generation
        let items = Array(selectedItems.prefix(requiredMemoryCount))
        guard !items.isEmpty else {
            drafts = []
            selectionWarning = nil
            return
        }

        isLoadingSelection = true
        selectionWarning = nil
        loadTask = Task { [weak self] in
            guard let self else { return }
            let loaded = await Self.load(items: items)
            guard !Task.isCancelled, generation == selectionGeneration else { return }
            drafts = loaded.drafts.sorted { $0.originalSelectionIndex < $1.originalSelectionIndex }
            selectionWarning = loaded.failureCount == 0
                ? nil
                : "\(loaded.failureCount)枚読み込めませんでした。別の写真を選べます。"
            isLoadingSelection = false
        }
    }

    func remove(_ draft: SeedMemoryDraft) {
        drafts.removeAll { $0.id == draft.id }
        if let assetIdentifier = draft.assetIdentifier {
            selectedItems.removeAll { $0.itemIdentifier == assetIdentifier }
        } else if selectedItems.indices.contains(draft.originalSelectionIndex) {
            selectedItems.remove(at: draft.originalSelectionIndex)
        }
    }

    private nonisolated static func load(items: [PhotosPickerItem]) async -> (drafts: [SeedMemoryDraft], failureCount: Int) {
        var drafts: [SeedMemoryDraft] = []
        var failureCount = 0
        var identifiers = Set<String>()

        for (index, item) in items.enumerated() {
            guard !Task.isCancelled else { break }
            if let identifier = item.itemIdentifier, !identifiers.insert(identifier).inserted { continue }
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = await LockUImageDecoder.downsample(data: data, maxDimension: 2400) else {
                    throw LockUStorageError.invalidImage
                }
                drafts.append(SeedMemoryDraft(
                    id: UUID(),
                    image: image,
                    capturedAt: creationDate(assetIdentifier: item.itemIdentifier) ?? .now,
                    assetIdentifier: item.itemIdentifier,
                    originalSelectionIndex: index
                ))
            } catch is CancellationError {
                break
            } catch {
                failureCount += 1
            }
        }
        return (drafts, failureCount)
    }

    private nonisolated static func creationDate(assetIdentifier: String?) -> Date? {
        guard let assetIdentifier else { return nil }
        return PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject?.creationDate
    }
}

struct FirstLockerOnboardingView: View {
    @StateObject private var model = FirstLockerOnboardingViewModel()
    @EnvironmentObject private var appModel: LockUAppModel
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository
    @State private var step: Step = .memories

    private enum Step { case memories, background, final }

    var body: some View {
        ZStack {
            SkyBackground()
            if model.drafts.isEmpty && !model.isLoadingSelection && step == .memories {
                intro
            } else {
                switch step {
                case .memories: selectionPreview
                case .background: backgroundSelection
                case .final: finalPreview
                }
            }
        }
        .onChange(of: model.selectedItems) { _, _ in model.selectionDidChange() }
    }

    private var intro: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("LockU")
                .font(.system(size: 16, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.72))
            Text("Your locker starts\nwith a few memories.")
                .font(.system(size: 30, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(LockUDesign.Color.schoolNavy)
            Text("まず、残しておきたい日常を\n少しだけ連れてこよう。")
                .font(LockUDesign.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(LockUDesign.Color.softInkSecondary)
            Spacer()
            pickerButton(title: "写真を選ぶ")
            Text("0 / \(model.requiredMemoryCount)")
                .font(LockUDesign.Typography.caption)
                .foregroundStyle(LockUDesign.Color.softInkSecondary)
                .accessibilityLabel("\(model.requiredMemoryCount)枚中0枚選択")
            Text("ロッカーに飾る思い出を\(model.requiredMemoryCount)枚選ぼう")
                .font(LockUDesign.Typography.caption)
                .foregroundStyle(LockUDesign.Color.softInkSecondary)
                .padding(.bottom, 34)
        }
        .padding(.horizontal, 28)
    }

    private var selectionPreview: some View {
        VStack(spacing: 16) {
            Text("Your memories")
                .font(LockUDesign.Typography.screenTitle)
                .foregroundStyle(LockUDesign.Color.schoolNavy)
                .padding(.top, 26)
            Text("\(model.drafts.count) / \(model.requiredMemoryCount)")
                .font(LockUDesign.Typography.caption)
                .foregroundStyle(LockUDesign.Color.softInkSecondary)
                .accessibilityLabel("\(model.requiredMemoryCount)枚中\(model.drafts.count)枚選択")

            if model.isLoadingSelection {
                ProgressView("写真を読み込んでいます")
                    .tint(LockUDesign.Color.schoolNavy)
                    .frame(maxHeight: .infinity)
            } else {
                GeometryReader { proxy in
                    ZStack {
                        ForEach(Array(model.drafts.enumerated()), id: \.element.id) { index, draft in
                            draftPreview(draft, index: index, size: proxy.size)
                        }
                    }
                }
            }

            if let warning = model.selectionWarning {
                Text(warning)
                    .font(LockUDesign.Typography.caption)
                    .foregroundStyle(LockUDesign.Color.warning)
                    .multilineTextAlignment(.center)
            } else if !model.canContinue {
                Text("あと\(max(0, model.requiredMemoryCount - model.drafts.count))枚選んでください")
                    .font(LockUDesign.Typography.caption)
                    .foregroundStyle(LockUDesign.Color.softInkSecondary)
            }

            Button("Continue") { step = .background }
                .buttonStyle(LockUPrimaryButtonStyle())
                .disabled(!model.canContinue)
                .opacity(model.canContinue ? 1 : 0.42)
                .accessibilityHint("背景選択へ進みます")

            pickerButton(title: "写真を追加・変更")
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }

    private var backgroundSelection: some View {
        VStack(spacing: 14) {
            Text("Choose your locker")
                .font(LockUDesign.Typography.screenTitle)
                .foregroundStyle(LockUDesign.Color.schoolNavy)
                .padding(.top, 24)
            SeedLockerPreview(drafts: model.drafts, backgroundStyle: model.selectedBackgroundStyle)
                .frame(maxHeight: 430)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(LockerBackgroundStyle.allCases) { style in
                        Button {
                            model.selectedBackgroundStyle = style
                        } label: {
                            VStack(spacing: 6) {
                                LockerInteriorBackground(style: style)
                                    .frame(width: 72, height: 52)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(model.selectedBackgroundStyle == style ? LockUDesign.Color.schoolNavy : .white.opacity(0.7), lineWidth: 2))
                                Text(style.title).font(.caption2)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(style.title)
                        .accessibilityAddTraits(model.selectedBackgroundStyle == style ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 3)
            }

            Button("Continue") { step = .final }
                .buttonStyle(LockUPrimaryButtonStyle())
            Button("思い出を変更") { step = .memories }
                .buttonStyle(LockUSecondaryButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
    }

    private var finalPreview: some View {
        VStack(spacing: 14) {
            Text("Your first locker")
                .font(LockUDesign.Typography.screenTitle)
                .foregroundStyle(LockUDesign.Color.schoolNavy)
                .padding(.top, 24)
            SeedLockerPreview(drafts: model.drafts, backgroundStyle: model.selectedBackgroundStyle)
                .frame(maxHeight: 450)
            Text(model.selectedBackgroundStyle.title)
                .font(LockUDesign.Typography.body)
                .foregroundStyle(LockUDesign.Color.schoolNavy)

            if let error = model.creationError {
                Text(error)
                    .font(LockUDesign.Typography.caption)
                    .foregroundStyle(LockUDesign.Color.warning)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(error)
            }

            Button {
                createMyLocker()
            } label: {
                if model.isCreatingLocker {
                    HStack(spacing: 9) { ProgressView(); Text("Creating your locker…") }
                } else {
                    Text("Create My Locker")
                }
            }
            .buttonStyle(LockUPrimaryButtonStyle())
            .disabled(model.isCreatingLocker || model.requiresRecovery)
            .accessibilityLabel(model.isCreatingLocker ? "ロッカーを作成中" : "最初のロッカーを作る")

            HStack(spacing: 22) {
                Button("思い出を変更") { step = .memories }
                Button("背景を変更") { step = .background }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(LockUDesign.Color.schoolNavy)
            .disabled(model.isCreatingLocker)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
    }

    private func createMyLocker() {
        guard !model.isCreatingLocker else { return }
        Task {
            let succeeded = await model.createLocker(
                memoryRepository: memoryRepository,
                settingsRepository: settingsRepository,
                now: .now
            )
            guard succeeded else { return }
            appModel.selectedTab = .locker
            appModel.lockerDoorState = .open
            appModel.completeFirstLocker()
        }
    }

    @MainActor
    private func pickerButton(title: String) -> some View {
        let loading = model.isLoadingSelection
        let requiredCount = model.requiredMemoryCount
        return PhotosPicker(selection: $model.selectedItems, maxSelectionCount: requiredCount, matching: .images) {
            HStack(spacing: 8) {
                if loading { ProgressView() }
                else { Image(systemName: "photo.on.rectangle.angled") }
                Text(loading ? "読み込んでいます…" : title)
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(LockUSecondaryButtonStyle())
        .disabled(loading)
        .accessibilityLabel("思い出にする写真を選ぶ")
    }

    private func draftPreview(_ draft: SeedMemoryDraft, index: Int, size: CGSize) -> some View {
        let anchors = [CGPoint(x: 0.19, y: 0.18), CGPoint(x: 0.54, y: 0.16), CGPoint(x: 0.80, y: 0.27), CGPoint(x: 0.25, y: 0.50), CGPoint(x: 0.70, y: 0.49), CGPoint(x: 0.20, y: 0.81), CGPoint(x: 0.70, y: 0.79)]
        let rotations = [-1.4, 0.8, 1.6, -0.6, 1.1, -1.8, 0.5]
        let widths: [CGFloat] = [0.29, 0.32, 0.25, 0.31, 0.34, 0.27, 0.32]
        let width = size.width * widths[index]
        return Image(uiImage: draft.image)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: width * (index.isMultiple(of: 2) ? 1.15 : 0.82))
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .rotationEffect(.degrees(rotations[index]))
            .position(x: size.width * anchors[index].x, y: size.height * anchors[index].y)
            .overlay(alignment: .topTrailing) {
                Button { model.remove(draft) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 19))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.52))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("選択した写真を外す")
                .offset(x: 13, y: -13)
            }
            .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
    }
}

private struct SeedLockerPreview: View {
    let drafts: [SeedMemoryDraft]
    let backgroundStyle: LockerBackgroundStyle

    private let anchors = [CGPoint(x: 0.19, y: 0.18), CGPoint(x: 0.54, y: 0.16), CGPoint(x: 0.80, y: 0.27), CGPoint(x: 0.25, y: 0.50), CGPoint(x: 0.70, y: 0.49), CGPoint(x: 0.20, y: 0.81), CGPoint(x: 0.70, y: 0.79)]
    private let rotations = [-1.4, 0.8, 1.6, -0.6, 1.1, -1.8, 0.5]
    private let widths: [CGFloat] = [0.29, 0.32, 0.25, 0.31, 0.34, 0.27, 0.32]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LockerInteriorBackground(style: backgroundStyle)
                ForEach(Array(drafts.prefix(LockerMemoryLayout.photoSlotCount).enumerated()), id: \.element.id) { index, draft in
                    let width = proxy.size.width * widths[index]
                    Image(uiImage: draft.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: width * (index.isMultiple(of: 2) ? 1.15 : 0.82))
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .rotationEffect(.degrees(rotations[index]))
                        .position(x: proxy.size.width * anchors[index].x, y: proxy.size.height * anchors[index].y)
                        .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.65), lineWidth: 1))
        }
        .aspectRatio(0.78, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("選択した写真と\(backgroundStyle.title)のロッカープレビュー")
    }
}
