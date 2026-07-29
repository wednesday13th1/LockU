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
            switch item {
            case .code:
                LockerCodeSheet(code: settingsRepository.settings.lockerNumber)
            case .settings:
                LockerSettingsSheet()
            case .share:
                ShareLockerSheet(code: settingsRepository.settings.lockerNumber)
            }
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
        VStack(spacing: 24) {
            Text("Locker Code").font(.title.bold())
            Text(code).font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text("このコードを友達に伝えると、今日の思い出をPeekできます。")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
        }.padding(32).presentationDetents([.medium])
    }
}

private struct ShareLockerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let code: String
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "paperplane.fill").font(.largeTitle)
            Text("Share your locker").font(.title2.bold())
            ShareLink(item: "My LockU Locker Code: \(code)") {
                Label("Share Locker Code", systemImage: "square.and.arrow.up")
            }.buttonStyle(.borderedProminent)
            Button("Close") { dismiss() }
        }.padding(32).presentationDetents([.medium])
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
                TextField("Owner name", text: $ownerName)
                TextField("Locker code", text: $lockerNumber)
                    .keyboardType(.numberPad)
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
