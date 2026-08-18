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
    @State private var ownerName = ""
    @State private var lockerNumber = ""

    var body: some View {
        NavigationStack {
            Form {
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
            }
        }
    }
}
