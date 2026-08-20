import PhotosUI
import SwiftUI
import UIKit

struct HallwayView: View {
    @State private var sheet: HallwaySheet?

    var body: some View {
        LockerHomeView(
            onSettings: { sheet = .settings }
        )
        .sheet(item: $sheet) { item in
            Group {
                switch item {
                case .settings:
                    LockerSettingsSheet()
                }
            }
            .presentationBackground(.ultraThinMaterial)
        }
    }

}

private enum HallwaySheet: Identifiable {
    case settings
    var id: Self { self }
}

private struct LockerSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repository: LockerSettingsRepository
    @EnvironmentObject private var appModel: LockUAppModel
    @EnvironmentObject private var backgroundRepository: BackgroundRepository
    @State private var ownerName = ""
    @State private var lockerNumber = ""
    @State private var doorMessage = LockerSettings.defaultDoorMessage
    @State private var selectedBackground: PhotosPickerItem?
    @State private var isImportingBackground = false

    var body: some View {
        NavigationStack {
            Form {
                Section("ロッカー") {
                    TextField("名前", text: $ownerName)
                }

                Section("背景") {
                    if let image = backgroundRepository.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 112)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button { setBackgroundMode(.today) } label: {
                        Label("今日の色", systemImage: repository.settings.backgroundMode == .today ? "largecircle.fill.circle" : "circle")
                    }
                    PhotosPicker(selection: $selectedBackground, matching: .images) {
                        Label("自分の写真", systemImage: repository.settings.backgroundMode == .photo ? "largecircle.fill.circle" : "circle")
                    }
                    .disabled(isImportingBackground)
                    if backgroundRepository.image != nil {
                        Button("初期背景に戻す", role: .destructive) { resetBackground() }
                    }
                    if isImportingBackground { ProgressView("読み込み中") }
                }

                Section("ドアのひとこと") {
                    TextField("放課後またね", text: $doorMessage)
                        .onChange(of: doorMessage) { _, value in
                            if value.count > LockerSettings.maximumDoorMessageLength {
                                doorMessage = String(value.prefix(LockerSettings.maximumDoorMessageLength))
                            }
                        }
                    Text("\(doorMessage.count) / \(LockerSettings.maximumDoorMessageLength)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                            settings.doorMessage = doorMessage
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
                doorMessage = repository.settings.doorMessage
            }
            .onChange(of: selectedBackground) { _, item in
                guard let item else { return }
                Task { await importBackground(from: item) }
            }
        }
    }

    private func resetBackground() {
        do {
            try backgroundRepository.remove()
            var settings = repository.settings
            settings.backgroundMode = .today
            try repository.update(settings)
        } catch { appModel.report(error) }
    }

    private func setBackgroundMode(_ mode: LockerSettings.BackgroundMode) {
        var settings = repository.settings
        settings.backgroundMode = mode == .photo && backgroundRepository.image == nil ? .today : mode
        do { try repository.update(settings) } catch { appModel.report(error) }
    }

    private func importBackground(from item: PhotosPickerItem) async {
        guard !isImportingBackground else { return }
        isImportingBackground = true
        defer { isImportingBackground = false; selectedBackground = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw LockUStorageError.invalidImage }
            let prepared = await Task.detached(priority: .userInitiated) {
                LockerBackgroundImagePreparation.downsample(data, maximumPixelSize: 2_048)
            }.value
            guard let prepared, let image = UIImage(data: prepared) else { throw LockUStorageError.invalidImage }
            try backgroundRepository.save(image)
            var settings = repository.settings
            settings.backgroundMode = .photo
            try repository.update(settings)
        } catch { appModel.report(error) }
    }
}
