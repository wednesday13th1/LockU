import SwiftUI
import UIKit

struct LockerDecorationLayer: View {
    @EnvironmentObject private var repository: DecorationRepository
    @State private var selectedID: UUID?
    let isEditing: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(repository.decorations) { decoration in
                    LockerDecorationItem(
                        decoration: decoration,
                        containerSize: proxy.size,
                        isEditing: isEditing,
                        isSelected: selectedID == decoration.id,
                        onSelect: { selectedID = decoration.id }
                    )
                    .zIndex(Double(decoration.zIndex))
                }
            }
        }
        .onChange(of: isEditing) { _, editing in if !editing { selectedID = nil } }
    }
}

private struct LockerDecorationItem: View {
    @EnvironmentObject private var repository: DecorationRepository
    @EnvironmentObject private var appModel: LockUAppModel
    let decoration: LockerDecoration
    let containerSize: CGSize
    let isEditing: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var liveMagnification: CGFloat = 1
    @GestureState private var liveRotation: Angle = .zero

    var body: some View {
        Group {
            if let image = repository.image(for: decoration) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo.badge.exclamationmark")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(
            width: max(48, min(containerSize.width * 0.20, 96)),
            height: max(48, min(containerSize.width * 0.20, 96))
        )
        .opacity(isSelected ? 0.96 : 0.88)
        .contentShape(Rectangle())
        .scaleEffect(
            x: decoration.isFlipped
                ? -decoration.scale * liveMagnification
                : decoration.scale * liveMagnification,
            y: decoration.scale * liveMagnification
        )
        .rotationEffect(.degrees(decoration.rotationDegrees) + liveRotation)
        .position(
            x: containerSize.width * decoration.position.x + dragTranslation.width,
            y: containerSize.height * decoration.position.y + dragTranslation.height
        )
        .overlay {
            if isEditing && isSelected {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(style: StrokeStyle(lineWidth: 0.8, dash: [4, 3]))
                    .foregroundStyle(Color(red: 247/255, green: 244/255, blue: 234/255).opacity(0.76))
                    .padding(-5)
                    .allowsHitTesting(false)
            }
        }
        .gesture(isEditing ? dragGesture : nil)
        .simultaneousGesture(isEditing ? magnificationGesture : nil)
        .simultaneousGesture(isEditing ? rotationGesture : nil)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onSelect()
            }
        )
        .onTapGesture {
            do {
                try LockerPlacementCoordinator(repository: repository).bringToFront(decoration)
                onSelect()
            } catch {
                appModel.report(error)
            }
        }
        .contextMenu {
            if isEditing {
                Button("手前に移動", systemImage: "square.3.layers.3d.top.filled") {
                    perform { try LockerPlacementCoordinator(repository: repository).bringToFront(decoration) }
                }
                Button("左右を反転", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                    perform { try LockerPlacementCoordinator(repository: repository).flip(decoration) }
                }
                Button("削除", systemImage: "trash", role: .destructive) {
                    perform { try repository.delete(decoration) }
                }
            }
        }
        .allowsHitTesting(isEditing)
        .accessibilityLabel("ロッカーの飾り")
        .accessibilityHint("Drag, pinch, or rotate to edit. Long press for options.")
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                perform {
                    try LockerPlacementCoordinator(repository: repository).move(decoration, by: CodablePoint(x: value.translation.width / max(containerSize.width, 1), y: value.translation.height / max(containerSize.height, 1)))
                }
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .updating($liveMagnification) { value, state, _ in
                state = value
            }
            .onEnded { value in
                perform {
                    try LockerPlacementCoordinator(repository: repository).scale(decoration, by: value)
                }
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .updating($liveRotation) { value, state, _ in
                state = value
            }
            .onEnded { value in
                perform {
                    try LockerPlacementCoordinator(repository: repository).rotate(decoration, by: value.degrees)
                }
            }
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            appModel.report(error)
        }
    }
}
