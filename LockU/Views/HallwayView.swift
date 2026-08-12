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
            Text("Locker Code").font(LockUDesign.Typography.screenTitle)
            Text(code)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .tracking(3)
            Text("このコードを友達に伝えると、今日の思い出をPeekできます。")
                .font(LockUDesign.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(LockUDesign.Color.softInkSecondary)
            Button("Close") { dismiss() }.buttonStyle(LockUPrimaryButtonStyle())
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
            Text("Share your locker").font(LockUDesign.Typography.screenTitle)
            Text("LOCKER CODE")
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
            ShareLink(item: "My LockU Locker Code: \(code)") {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LockUPrimaryButtonStyle())
            Button("Close") { dismiss() }.buttonStyle(LockUSecondaryButtonStyle())
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
                    }
                    .frame(height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.42), lineWidth: 1))
                    .allowsHitTesting(false)
                    .accessibilityLabel("Current Locker Home preview")
                }

                Section("Locker Appearance") {
                    Picker("Locker Background", selection: $appearance.backgroundStyle) {
                        ForEach(LockerBackgroundStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Collage Style", selection: $appearance.collageStyle) {
                        ForEach(LockerCollageStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Frame", selection: $appearance.frameStyle) {
                        ForEach(LockerFrameStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Filter", selection: $appearance.filterStyle) {
                        ForEach(LockerFilterStyle.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Featured Video", selection: $appearance.featuredVideoMemoryID) {
                        Text("Automatic — Latest Memory").tag(UUID?.none)
                        ForEach(memoryRepository.memories) { memory in
                            Text(memory.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .tag(Optional(memory.id))
                        }
                    }
                    Toggle("Daily Variation", isOn: $appearance.dailyVariationEnabled)
                }

                Section("Locker") {
                    TextField("Owner name", text: $ownerName)
                    TextField("Locker code", text: $lockerNumber)
                        .keyboardType(.numberPad)
                }

                #if DEBUG
                Section("Demo Time") {
                    Picker("Time", selection: Binding(
                        get: { appModel.demoClock.preset },
                        set: { appModel.selectDemoPreset($0) }
                    )) {
                        ForEach(LockUDemoTimePreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    Text("Session only · Memory dates are never changed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                #endif
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
