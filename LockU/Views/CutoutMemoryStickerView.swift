import SwiftUI
import UIKit

struct CutoutMemoryStickerView: View {
    @EnvironmentObject private var repository: MemoryRepository
    @EnvironmentObject private var appModel: LockUAppModel
    let memory: MemoryRecord

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            appModel.selectedTab = .locker
        } label: {
            Group {
                if let image = repository.image(for: memory) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .shadow(color: .white.opacity(0.95), radius: 2, x: 2)
                        .shadow(color: .white.opacity(0.95), radius: 2, x: -2)
                        .shadow(color: .white.opacity(0.95), radius: 2, y: 2)
                        .shadow(color: .white.opacity(0.95), radius: 2, y: -2)
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 3)
                } else {
                    Image(systemName: "photo.badge.exclamationmark")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .buttonStyle(LockerPressStyle())
        .accessibilityLabel(
            "Cutout memory from \(memory.createdAt.formatted(date: .long, time: .omitted))"
        )
        .accessibilityHint("ロッカーの写真を開きます")
    }
}
