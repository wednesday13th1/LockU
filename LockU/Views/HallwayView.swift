import SwiftUI

struct HallwayView: View {
    @EnvironmentObject private var settingsRepository: LockerSettingsRepository
    @State private var sheet: HallwaySheet?

    var body: some View {
        LockerHomeView(
            onShare: { sheet = .share },
            onCode: { sheet = .code },
            onSettings: { sheet = .settings }
        )
        .sheet(item: $sheet) { item in
            Group {
                switch item {
                case .code:
                    LockerCodeSheet(code: settingsRepository.settings.lockerNumber)
                case .settings:
                    LockerSettingsSheet()
                case .share:
                    ShareLockerSheet(code: settingsRepository.settings.lockerNumber)
                }
            }
            .presentationBackground(.ultraThinMaterial)
        }
    }

}

private enum HallwaySheet: Identifiable {
    case share, code, settings
    var id: Self { self }
}

private struct LockerCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let code: String
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "number.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(LockUDesign.Color.ramuneBlue)
            Text("ロッカーコード").font(LockUDesign.Typography.screenTitle)
            Text(code)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .tracking(3)
            Text("このコードを友達に伝えると、今日の思い出をPeekできます。")
                .font(LockUDesign.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(LockUDesign.Color.softInkSecondary)
            Button("閉じる") { dismiss() }.buttonStyle(LockUPrimaryButtonStyle())
        }
        .foregroundStyle(LockUDesign.Color.schoolNavy)
        .padding(32)
        .presentationDetents([.medium])
        .presentationCornerRadius(32)
    }
}

private struct ShareLockerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let code: String
    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(LockUDesign.Color.ramuneBlue.opacity(0.35))
                .frame(width: 52, height: 5)
            Image(systemName: "paperplane.fill")
                .font(.system(size: 36))
                .foregroundStyle(LockUDesign.Color.ramuneBlue)
            Text("ロッカーをシェア").font(LockUDesign.Typography.screenTitle)
            Text("ロッカーコード")
                .font(LockUDesign.Typography.caption)
                .tracking(2)
                .foregroundStyle(LockUDesign.Color.softInkSecondary)
            HStack(spacing: 18) {
                Text(code)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(3)
                Image(systemName: "qrcode")
                    .font(.system(size: 48))
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(LockUDesign.Color.notebookPaper, in: RoundedRectangle(cornerRadius: 18))
            ShareLink(item: "LockUのロッカーコード：\(code)") {
                Label("シェア", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LockUPrimaryButtonStyle())
            Button("閉じる") { dismiss() }.buttonStyle(LockUSecondaryButtonStyle())
        }
        .foregroundStyle(LockUDesign.Color.schoolNavy)
        .padding(28)
        .background(
            LinearGradient(
                colors: [LockUDesign.Color.summerSkyMiddle.opacity(0.28), .clear],
                startPoint: .top,
                endPoint: .center
            )
        )
        .presentationDetents([.medium])
        .presentationCornerRadius(32)
    }
}

private struct LockerSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repository: LockerSettingsRepository
    @EnvironmentObject private var appModel: LockUAppModel
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @StateObject private var previewResurfacingCoordinator = LockerResurfacingCoordinator()
    @StateObject private var previewCanvasEditingCoordinator = LockerCanvasEditingCoordinator()
    @State private var ownerName = ""
    @State private var lockerNumber = ""
    @State private var appearance = LockerAppearanceSettings.default

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack {
                        LockerInteriorBackground(style: appearance.backgroundStyle)
                        LockerMemoryBoardView(appearanceOverride: appearance)
                            .environmentObject(memoryRepository)
                            .environmentObject(appModel)
                            .environmentObject(previewResurfacingCoordinator)
                            .environmentObject(previewCanvasEditingCoordinator)
                    }
                    .frame(height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.42), lineWidth: 1))
                    .allowsHitTesting(false)
                    .accessibilityLabel("現在のロッカープレビュー")
                }

                Section("見た目") {
                    Picker("背景", selection: $appearance.backgroundStyle) {
                        ForEach(LockerBackgroundStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("コラージュ", selection: $appearance.collageStyle) {
                        ForEach(LockerCollageStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("フレーム", selection: $appearance.frameStyle) {
                        ForEach(LockerFrameStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("フィルター", selection: $appearance.filterStyle) {
                        ForEach(LockerFilterStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("棚の雰囲気", selection: $appearance.itemTheme) {
                        ForEach(LockerItemTheme.allCases) { theme in
                            Text(theme.title)
                                .tag(theme)
                                .accessibilityLabel("\(theme.title)のテーマ")
                        }
                    }
                    Picker("動く思い出", selection: $appearance.featuredVideoMemoryID) {
                        Text("自動・最新の思い出").tag(UUID?.none)
                        ForEach(memoryRepository.memories) { memory in
                            Text(memory.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .tag(Optional(memory.id))
                        }
                    }
                    Toggle("日ごとに少し変える", isOn: $appearance.dailyVariationEnabled)
                }

                Section("ロッカー") {
                    TextField("名前", text: $ownerName)
                    TextField("ロッカーコード", text: $lockerNumber)
                        .keyboardType(.numberPad)
                }

                #if DEBUG
                Section("デモ時刻") {
                    Picker("時刻", selection: Binding(
                        get: { appModel.demoClock.preset },
                        set: { appModel.selectDemoPreset($0) }
                    )) {
                        ForEach(LockUDemoTimePreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    Text("この起動中のみ・思い出の日付は変わりません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #endif
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do {
                            var settings = repository.settings
                            settings.ownerName = ownerName.isEmpty ? "My" : ownerName
                            settings.lockerNumber = lockerNumber.isEmpty ? "24" : lockerNumber
                            settings.appearance = appearance
                            try repository.update(settings)
                            dismiss()
                        } catch {
                            appModel.report(error)
                        }
                    }
                }
            }
            .onAppear {
                ownerName = repository.settings.ownerName
                lockerNumber = repository.settings.lockerNumber
                appearance = repository.settings.appearance
            }
        }
    }
}
