import PhotosUI
import SwiftUI
import UIKit

struct LockerInteriorContent: View {
    @EnvironmentObject private var appModel: LockUAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lightOn = false
    @State private var shelfVisible = false
    let isCustomizingTopShelf: Bool

    var body: some View {
        GeometryReader { proxy in
            let topShelfHeight = max(54.0, proxy.size.height * 0.14)
            let bottomShelfHeight = max(78.0, proxy.size.height * 0.17)

            VStack(spacing: 0) {
                LockerTopShelfView(isEditing: isCustomizingTopShelf)
                    .frame(height: topShelfHeight)
                    .opacity(shelfVisible ? 1 : 0)
                    .offset(y: shelfVisible ? 0 : 5)

                LockerMemoryBoardView()
                    .frame(maxHeight: .infinity)

                LockerBottomShelfView()
                    .frame(height: bottomShelfHeight)
                    .opacity(shelfVisible ? 1 : 0)
                    .offset(y: shelfVisible ? 0 : 7)
            }
            .overlay(alignment: .top) {
                LockerLightView(isOn: lightOn)
                    .frame(width: min(proxy.size.width * 0.62, 290), height: proxy.size.height * 0.34)
                    .allowsHitTesting(false)
            }
            .onAppear {
                updateVisibility(for: appModel.lockerDoorState)
            }
            .onChange(of: appModel.lockerDoorState) { _, state in
                updateVisibility(for: state)
            }
        }
    }

    private func updateVisibility(for state: LockerDoorState) {
        let visible = state.isOpenOrOpening
        if reduceMotion {
            lightOn = visible
            shelfVisible = visible
        } else {
            withAnimation(.easeOut(duration: 0.3).delay(visible ? 0.16 : 0)) {
                lightOn = visible
            }
            withAnimation(.easeOut(duration: 0.36).delay(visible ? 0.2 : 0)) {
                shelfVisible = visible
            }
        }
    }
}

private struct LockerLightView: View {
    let isOn: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(.clear).frame(height: 2)
            RadialGradient(
                colors: [
                    .white.opacity(isOn ? 0.15 : 0),
                    LockUDesign.Color.sunlight.opacity(isOn ? 0.055 : 0),
                    .clear
                ],
                center: .top,
                startRadius: 8,
                endRadius: 180
            )
        }
        .opacity(isOn ? 1 : 0.35)
    }
}

struct LockerTopShelfView: View {
    @EnvironmentObject private var repository: LockerCanvasRepository
    @EnvironmentObject private var appModel: LockUAppModel
    let isEditing: Bool
    @State private var selection: PhotosPickerItem?
    @State private var selectedID: UUID?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                ForEach(repository.metadata.topShelfDecorations) { decoration in
                    LockerTopShelfDecorationItem(
                        decoration: decoration,
                        containerSize: proxy.size,
                        isEditing: isEditing,
                        isSelected: selectedID == decoration.id,
                        onSelect: { selectedID = decoration.id }
                    )
                    .zIndex(Double(decoration.zIndex))
                }

                shelf
                    .zIndex(100)
                    .allowsHitTesting(false)

                if isEditing {
                    addControl
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.trailing, 5)
                        .zIndex(200)
                }
            }
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task { await importDecoration(item) }
        }
        .onChange(of: isEditing) { _, editing in if !editing { selectedID = nil } }
    }

    @ViewBuilder
    private var addControl: some View {
        if repository.metadata.topShelfDecorations.count < LockerCanvasRepository.maximumTopShelfDecorations {
            PhotosPicker(selection: $selection, matching: .images) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
            }
            .accessibilityLabel("上の棚に画像を追加")
        } else {
            Button {
                appModel.report(LockerCanvasError.topShelfDecorationLimitReached)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
            }
            .accessibilityLabel("上の棚に画像を追加")
        }
    }

    @MainActor
    private func importDecoration(_ item: PhotosPickerItem) async {
        defer { selection = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { throw LockUStorageError.invalidImage }
            let added = try repository.addTopShelfDecoration(image: image)
            selectedID = added.id
        } catch {
            appModel.report(error)
        }
    }

    private var shelf: some View {
        VStack(spacing: 0) {
            TrapezoidTopShelf().fill(Color(red: 169/255, green: 176/255, blue: 178/255)).frame(height: 5)
            Rectangle().fill(Color(red: 115/255, green: 124/255, blue: 128/255)).frame(height: 6)
            Rectangle().fill(.black.opacity(0.20)).frame(height: 7).blur(radius: 3)
        }
        .padding(.horizontal, 1.5)
    }
}

private struct LockerTopShelfDecorationItem: View {
    @EnvironmentObject private var repository: LockerCanvasRepository
    @EnvironmentObject private var appModel: LockUAppModel
    let decoration: LockerTopShelfDecoration
    let containerSize: CGSize
    let isEditing: Bool
    let isSelected: Bool
    let onSelect: () -> Void

    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var liveMagnification: CGFloat = 1
    @GestureState private var liveRotation: Angle = .zero

    var body: some View {
        Group {
            if let image = repository.topShelfImage(for: decoration) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "photo.badge.exclamationmark").foregroundStyle(.secondary)
            }
        }
        .frame(width: max(34, containerSize.width * 0.14), height: max(34, containerSize.width * 0.14))
        .scaleEffect(decoration.scale * liveMagnification)
        .rotationEffect(.degrees(decoration.rotationDegrees) + liveRotation)
        .position(
            x: containerSize.width * decoration.normalizedX + dragTranslation.width,
            y: containerSize.height * decoration.normalizedY + dragTranslation.height
        )
        .shadow(color: .black.opacity(0.11), radius: 3, y: 1.5)
        .overlay {
            if isEditing && isSelected {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(-5)
                    .overlay(alignment: .topTrailing) {
                        Button { remove() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .frame(width: 28, height: 28)
                                .background(.thinMaterial, in: Circle())
                        }
                        .offset(x: 12, y: -12)
                        .accessibilityLabel("上棚の画像を削除")
                    }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if isEditing { onSelect() } }
        .gesture(isEditing ? dragGesture : nil)
        .simultaneousGesture(isEditing ? magnificationGesture : nil)
        .simultaneousGesture(isEditing ? rotationGesture : nil)
        .allowsHitTesting(isEditing)
        .accessibilityLabel("上棚の画像デコレーション")
        .accessibilityHint(isEditing ? "ドラッグ、拡大、回転できます" : "")
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .updating($dragTranslation) { value, state, _ in state = value.translation }
            .onEnded { value in
                var updated = decoration
                updated.normalizedX = min(0.86, max(0.14, decoration.normalizedX + value.translation.width / max(containerSize.width, 1)))
                updated.normalizedY = min(0.68, max(0.18, decoration.normalizedY + value.translation.height / max(containerSize.height, 1)))
                save(updated)
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .updating($liveMagnification) { value, state, _ in state = value }
            .onEnded { value in
                var updated = decoration
                updated.scale = min(1.35, max(0.45, decoration.scale * value))
                save(updated)
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .updating($liveRotation) { value, state, _ in state = value }
            .onEnded { value in
                var updated = decoration
                updated.rotationDegrees += value.degrees
                save(updated)
            }
    }

    private func save(_ updated: LockerTopShelfDecoration) {
        do { try repository.updateTopShelfDecoration(updated); onSelect() }
        catch { appModel.report(error) }
    }

    private func remove() {
        do { try repository.deleteTopShelfDecoration(decoration) }
        catch { appModel.report(error) }
    }
}

private struct TrapezoidTopShelf: Shape {
    func path(in r: CGRect) -> Path { Path { p in p.move(to: CGPoint(x: 2, y: 0)); p.addLine(to: CGPoint(x: r.width-2, y: 0)); p.addLine(to: CGPoint(x: r.width, y: r.height)); p.addLine(to: CGPoint(x: 0, y: r.height)); p.closeSubpath() } }
}
