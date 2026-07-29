import SwiftUI

struct LockerInterior: View {
    @EnvironmentObject private var repository: DecorationRepository

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [LockUDesign.Color.ink, .black.opacity(0.88)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 3)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.28)
                ForEach(repository.decorations) { decoration in
                    if let image = repository.image(for: decoration) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: min(proxy.size.width * 0.42, 120))
                            .scaleEffect(
                                x: decoration.isFlipped ? -decoration.scale : decoration.scale,
                                y: decoration.scale
                            )
                            .rotationEffect(.degrees(decoration.rotationDegrees))
                            .position(
                                x: proxy.size.width * decoration.position.x,
                                y: proxy.size.height * decoration.position.y
                            )
                            .zIndex(Double(decoration.zIndex))
                    }
                }
                if repository.decorations.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled").font(.title)
                        Text("Your memories live here")
                            .font(.footnote)
                    }
                    .foregroundStyle(.white.opacity(0.55))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.14), lineWidth: 5))
        }
    }
}
