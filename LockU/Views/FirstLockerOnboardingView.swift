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
            updatedSettings.backgroundMode = .today
            updatedSettings.appearance.backgroundStyle = LockerDailyBackgroundProvider.style(for: now)
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
    @State private var introPage = 0

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
        VStack(spacing: 10) {
            TabView(selection: $introPage) {
                onboardingPage(
                    index: 0,
                    title: "なんでもない今日も、\n残しておこう。",
                    subtitle: "誰かに見せるためじゃなく、\n未来の自分のために。"
                )
                onboardingPage(
                    index: 1,
                    title: "その時の自分も、一緒に。",
                    subtitle: "楽しい日も、\n疲れた日も、そのままで。"
                )
                onboardingPage(
                    index: 2,
                    title: "いつか、今日にまた会える。",
                    subtitle: "忘れた頃に、\n過去の自分をもう一度。"
                )
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            if introPage < 2 {
                Button("次へ") {
                    withAnimation(.easeOut(duration: 0.28)) { introPage += 1 }
                }
                .buttonStyle(LockUPrimaryButtonStyle())
            } else {
                pickerButton(title: "最初に残しておきたい写真を選ぶ")
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
    }

    private func onboardingPage(index: Int, title: String, subtitle: String) -> some View {
        VStack(spacing: 22) {
            Text("LockU")
                .font(.system(size: 14, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.62))
                .padding(.top, 28)
            OnboardingLockerJourneyVisual(stage: index)
                .frame(maxWidth: 280, maxHeight: 350)
            Text(title)
                .font(.system(size: 29, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(LockUDesign.Color.schoolNavy)
            Text(subtitle)
                .font(LockUDesign.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(LockUDesign.Color.softInkSecondary)
            Spacer(minLength: 8)
        }
        .tag(index)
    }

    private var selectionPreview: some View {
        VStack(spacing: 16) {
            Text("最初に残しておきたい写真")
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
                Text("あと\(max(0, model.requiredMemoryCount - model.drafts.count))枚選べます")
                    .font(LockUDesign.Typography.caption)
                    .foregroundStyle(LockUDesign.Color.softInkSecondary)
            }

            Button("次へ") { step = .final }
                .buttonStyle(LockUPrimaryButtonStyle())
                .disabled(!model.canContinue)
                .opacity(model.canContinue ? 1 : 0.42)
                .accessibilityHint("最初のLocker確認へ進みます")

            pickerButton(title: "写真を追加・変更")
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }

    private var backgroundSelection: some View {
        VStack(spacing: 14) {
            Text("写真を置いておく場所")
                .font(LockUDesign.Typography.screenTitle)
                .foregroundStyle(LockUDesign.Color.schoolNavy)
                .padding(.top, 24)
            SeedLockerPreview(drafts: model.drafts, backgroundStyle: LockerDailyBackgroundProvider.style(for: .now))
                .frame(maxHeight: 430)
            Label("今日の色", systemImage: "sparkles")
                .font(LockUDesign.Typography.caption)
                .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.68))

            Button("次へ") { step = .final }
                .buttonStyle(LockUPrimaryButtonStyle())
            Button("思い出を変更") { step = .memories }
                .buttonStyle(LockUSecondaryButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
    }

    private var finalPreview: some View {
        VStack(spacing: 14) {
            Text("自分だけのLocker")
                .font(LockUDesign.Typography.screenTitle)
                .foregroundStyle(LockUDesign.Color.schoolNavy)
                .padding(.top, 24)
            SeedLockerPreview(drafts: model.drafts, backgroundStyle: LockerDailyBackgroundProvider.style(for: .now))
                .frame(maxHeight: 450)
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
                    HStack(spacing: 9) { ProgressView(); Text("準備しています…") }
                } else {
                    Text("自分だけのLockerをはじめる")
                }
            }
            .buttonStyle(LockUPrimaryButtonStyle())
            .disabled(model.isCreatingLocker || model.requiresRecovery)
            .accessibilityLabel(model.isCreatingLocker ? "ロッカーを準備中" : "自分だけのLockerをはじめる")

            Button("写真を変更") { step = .memories }
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

private struct OnboardingLockerJourneyVisual: View {
    let stage: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color(red: 181/255, green: 194/255, blue: 198/255))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: 137/255, green: 151/255, blue: 156/255).opacity(0.72))
                    .padding(13)

                photo(x: 0.36, y: 0.35, width: 0.38, rotation: -1.4, color: .white)
                if stage >= 1 {
                    photo(x: 0.68, y: 0.61, width: 0.32, rotation: 1.7, color: LockUDesign.Color.notebookPaper)
                    Text("😆  😌  🥹  🥱")
                        .font(.system(size: 17))
                        .position(x: proxy.size.width * 0.48, y: proxy.size.height * 0.78)
                    Text("8.14  ♡")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.76))
                        .rotationEffect(.degrees(-4))
                        .position(x: proxy.size.width * 0.30, y: proxy.size.height * 0.66)
                }
                if stage >= 2 {
                    photo(x: 0.29, y: 0.72, width: 0.28, rotation: -2, color: Color.white.opacity(0.94))
                    Text("92 DAYS AGO")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(LockUDesign.Color.schoolNavy.opacity(0.66))
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(LockUDesign.Color.notebookPaper.opacity(0.9), in: RoundedRectangle(cornerRadius: 3))
                        .position(x: proxy.size.width * 0.70, y: proxy.size.height * 0.24)
                }
            }
        }
        .aspectRatio(0.72, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func photo(x: CGFloat, y: CGFloat, width: CGFloat, rotation: Double, color: Color) -> some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle().fill(color)
                LinearGradient(colors: [LockUDesign.Color.ramuneBlue.opacity(0.42), LockUDesign.Color.schoolNavy.opacity(0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .padding(5)
            }
            .frame(width: proxy.size.width * width, height: proxy.size.width * width * 1.12)
            .rotationEffect(.degrees(rotation))
            .position(x: proxy.size.width * x, y: proxy.size.height * y)
            .shadow(color: .black.opacity(0.10), radius: 3, y: 2)
        }
    }
}
