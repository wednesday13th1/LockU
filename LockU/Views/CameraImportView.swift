import PhotosUI
import SwiftUI

struct CameraImportView: View {
    @EnvironmentObject private var memories: MemoryRepository
    @EnvironmentObject private var decorations: DecorationRepository
    @EnvironmentObject private var appModel: LockUAppModel
    @State private var selection: PhotosPickerItem?
    @State private var importedImage: UIImage?
    @State private var isLoading = false
    @State private var savedMemory: MemoryRecord?

    private var capturedToday: Bool { memories.hasMemory(on: .now) }

    var body: some View {
        ScrollView {
            VStack(spacing: LockUDesign.Spacing.large) {
                VStack(spacing: 6) {
                    Text("今日").font(.largeTitle.bold())
                    Text(capturedToday ? "今日の思い出は残してあります。" : "今日をひとつ残す。")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                preview

                if capturedToday && savedMemory == nil {
                    Label("思い出は1日ひとつ", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(LockUDesign.Color.ink)
                        .padding()
                        .background(.thinMaterial, in: Capsule())
                } else {
                    PhotosPicker(selection: $selection, matching: .images) {
                        Label("写真ライブラリから選ぶ", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LockUDesign.Color.ink)
                    .disabled(isLoading || capturedToday)
                    .onChange(of: selection) { _, item in
                        guard let item else { return }
                        Task { await importItem(item) }
                    }
                }

                if let image = importedImage, savedMemory != nil {
                    Button {
                        do {
                            try decorations.add(image: image)
                            importedImage = nil
                            appModel.selectedTab = .locker
                        } catch {
                            appModel.report(error)
                        }
                    } label: {
                        Label("ロッカーに残す", systemImage: "cabinet.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(LockUDesign.Spacing.large)
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let image = importedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .aspectRatio(4 / 5, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: LockUDesign.Radius.medium))
                .shadow(color: LockUDesign.shadow, radius: 18, y: 8)
        } else {
            RoundedRectangle(cornerRadius: LockUDesign.Radius.medium)
                .fill(.thinMaterial)
                .aspectRatio(4 / 5, contentMode: .fit)
                .overlay {
                    Image(systemName: isLoading ? "hourglass" : "camera")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func importItem(_ item: PhotosPickerItem) async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw LockUStorageError.invalidImage
            }
            let record = try memories.saveImage(image)
            importedImage = image
            savedMemory = record
        } catch {
            appModel.report(error)
            selection = nil
        }
    }
}
