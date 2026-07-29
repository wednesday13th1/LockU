import SwiftUI
import UIKit

struct LockerDecorationLayer: View {
    @EnvironmentObject private var repository: DecorationRepository
    @State private var selectedID: UUID?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(repository.decorations) { decoration in
                    LockerDecorationItem(
                        decoration: decoration,
                        containerSize: proxy.size,
                        isSelected: selectedID == decoration.id,
                        onSelect: { selectedID = decoration.id }
                    )
                    .zIndex(Double(decoration.zIndex))
                }
            }
        }
    }
}

private struct LockerDecorationItem: View {
    @EnvironmentObject private var repository: DecorationRepository
    @EnvironmentObject private var appModel: LockUAppModel
    let decoration: LockerDecoration
    let containerSize: CGSize
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
            width: max(54, min(containerSize.width * 0.24, 118)),
            height: max(54, min(containerSize.width * 0.24, 118))
        )
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
            if isSelected {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    .padding(-5)
                    .allowsHitTesting(false)
            }
        }
        .gesture(dragGesture)
        .simultaneousGesture(magnificationGesture)
        .simultaneousGesture(rotationGesture)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onSelect()
            }
        )
        .onTapGesture {
            do {
                try repository.bringToFront(decoration)
                onSelect()
            } catch {
                appModel.report(error)
            }
        }
        .contextMenu {
            Button("Bring to Front", systemImage: "square.3.layers.3d.top.filled") {
                perform { try repository.bringToFront(decoration) }
            }
            Button("Flip", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                perform {
                    guard var current = repository.decoration(id: decoration.id) else {
                        throw LockUStorageError.recordNotFound
                    }
                    current.isFlipped.toggle()
                    try repository.update(current)
                }
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                perform { try repository.delete(decoration) }
            }
        }
        .accessibilityLabel("Locker decoration")
        .accessibilityHint("Drag, pinch, or rotate to edit. Long press for options.")
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                perform {
                    guard var current = repository.decoration(id: decoration.id) else {
                        throw LockUStorageError.recordNotFound
                    }
                    let x = current.position.x + value.translation.width / max(containerSize.width, 1)
                    let y = current.position.y + value.translation.height / max(containerSize.height, 1)
                    current.position = CodablePoint(
                        x: min(max(x, 0.04), 0.96),
                        y: min(max(y, 0.04), 0.96)
                    )
                    try repository.update(current)
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
                    guard var current = repository.decoration(id: decoration.id) else {
                        throw LockUStorageError.recordNotFound
                    }
                    current.scale = min(max(current.scale * value, 0.3), 3)
                    try repository.update(current)
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
                    guard var current = repository.decoration(id: decoration.id) else {
                        throw LockUStorageError.recordNotFound
                    }
                    current.rotationDegrees += value.degrees
                    try repository.update(current)
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
