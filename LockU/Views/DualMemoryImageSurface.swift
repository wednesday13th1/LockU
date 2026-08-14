import SwiftUI
import UIKit

/// Composes the independently stored dual-camera originals at display time.
/// No flattened derivative is created or persisted.
struct DualMemoryImageSurface: View {
    enum MainCamera: Hashable {
        case back
        case front
    }

    @EnvironmentObject private var repository: MemoryRepository
    @State private var backImage: UIImage?
    @State private var frontImage: UIImage?

    let memory: MemoryRecord
    let purpose: MemoryImagePurpose
    let targetPointSize: CGSize
    var mainCamera: MainCamera = .back
    var overlayCorner: Alignment = .topTrailing

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: overlayCorner) {
                mainImage
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                if let overlay = overlayImage {
                    polaroidOverlay(image: overlay, containerWidth: proxy.size.width)
                        .padding(max(5, proxy.size.width * 0.045))
                }
            }
        }
        .task(id: loadKey) { await loadImages() }
        .onDisappear {
            backImage = nil
            frontImage = nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("その時に見ていた景色と、その時の自分")
    }

    @ViewBuilder
    private var mainImage: some View {
        if let image = resolvedMainImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color(white: 0.52)
                .overlay(Image(systemName: "photo").foregroundStyle(.white.opacity(0.65)))
        }
    }

    private func polaroidOverlay(image: UIImage, containerWidth: CGFloat) -> some View {
        let width = max(28, containerWidth * 0.29)
        let sideBorder = max(3, width * 0.065)
        let bottomBorder = max(6, width * 0.13)

        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: width - sideBorder * 2, height: (width - sideBorder * 2) * 1.25)
            .clipped()
            .padding(.horizontal, sideBorder)
            .padding(.top, sideBorder)
            .padding(.bottom, bottomBorder)
            .background(Color(red: 0.975, green: 0.97, blue: 0.95))
            .clipShape(RoundedRectangle(cornerRadius: max(2, width * 0.035)))
            .rotationEffect(.degrees(overlayRotation))
            .shadow(color: .black.opacity(0.13), radius: max(3, width * 0.055), y: max(2, width * 0.025))
    }

    private var resolvedMainImage: UIImage? {
        switch mainCamera {
        case .back: backImage ?? frontImage
        case .front: frontImage ?? backImage
        }
    }

    private var overlayImage: UIImage? {
        guard backImage != nil, frontImage != nil else { return nil }
        return mainCamera == .back ? frontImage : backImage
    }

    private var overlayRotation: Double {
        let checksum = memory.id.uuidString.utf8.reduce(0) { ($0 &* 31 + Int($1)) % 997 }
        return [-1.2, -0.5, 0.6, 1.1][checksum % 4]
    }

    private var loadKey: String {
        "\(memory.id.uuidString)-\(purpose.rawValue)-\(Int(targetPointSize.width.rounded()))x\(Int(targetPointSize.height.rounded()))"
    }

    private func loadImages() async {
        let loadedBack = await repository.backImageAsync(
            for: memory,
            purpose: purpose,
            targetPointSize: targetPointSize
        )
        let loadedFront = await repository.frontImageAsync(
            for: memory,
            purpose: purpose,
            targetPointSize: overlayTargetSize
        )
        guard !Task.isCancelled else { return }
        backImage = loadedBack
        frontImage = loadedFront
    }

    private var overlayTargetSize: CGSize {
        CGSize(width: max(80, targetPointSize.width * 0.34), height: max(100, targetPointSize.height * 0.34))
    }
}
