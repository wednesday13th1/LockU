import PencilKit
import SwiftUI

@MainActor
final class LockerCanvasEditingCoordinator: ObservableObject {
    enum Selection { case none, text, memory }
    @Published private(set) var isEditing = false
    @Published var isDrawing = false
    @Published var erasing = false
    @Published var penColor = UIColor.white
    @Published var penWidth: CGFloat = 3
    @Published private(set) var beginToken = 0
    @Published private(set) var finishToken = 0
    @Published private(set) var textToken = 0
    @Published private(set) var memoryToken = 0
    @Published private(set) var removeToken = 0
    @Published private(set) var bringToFrontToken = 0
    @Published var selection: Selection = .none

    func begin() { guard !isEditing else { return }; isEditing = true; beginToken &+= 1 }
    func finish() { guard isEditing else { return }; finishToken &+= 1; isEditing = false; isDrawing = false; selection = .none }
    func toggleDrawing() { isDrawing.toggle(); selection = .none }
    func requestText() { isDrawing = false; selection = .none; textToken &+= 1 }
    func requestMemory() { isDrawing = false; selection = .none; memoryToken &+= 1 }
    func removeSelection() { guard selection != .none else { return }; removeToken &+= 1; selection = .none }
    func bringSelectionToFront() { guard selection == .memory else { return }; bringToFrontToken &+= 1 }
    func undoDrawing() { NotificationCenter.default.post(name: .lockerCanvasUndo, object: nil) }
}

struct LockerCanvasLayer: View {
    @EnvironmentObject private var canvasRepository: LockerCanvasRepository
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var editingCoordinator: LockerCanvasEditingCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var texts: [LockerTextDecoration] = []
    @State private var placements: [LockerMemoryPlacement] = []
    @State private var selectedTextID: UUID?
    @State private var selectedPlacementID: UUID?
    @State private var drawing = PKDrawing()
    @State private var drawingSize: CGSize = .zero
    @State private var currentCanvasSize: CGSize = .zero
    @State private var showTextEntry = false
    @State private var textEntry = ""
    @State private var showMemoryPicker = false
    @State private var errorMessage: String?
    @State private var snapshot: Snapshot?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                LockerPencilCanvas(
                    drawing: $drawing, canvasSize: proxy.size, referenceSize: drawingSize,
                    isDrawingEnabled: editingCoordinator.isEditing && editingCoordinator.isDrawing,
                    color: editingCoordinator.penColor,
                    width: editingCoordinator.penWidth,
                    isEraser: editingCoordinator.erasing
                )
                .opacity(editingCoordinator.isEditing && editingCoordinator.isDrawing ? 0.68 : 0.46)
                .allowsHitTesting(editingCoordinator.isEditing && editingCoordinator.isDrawing)

                ForEach(texts) { decoration in
                    lockerText(decoration, size: proxy.size)
                }

                ForEach(placements.sorted { $0.zIndex < $1.zIndex }) { placement in
                    if let memory = memoryRepository.memories.first(where: { $0.id == placement.memoryID }) {
                        lockerMemory(memory, placement: placement, size: proxy.size)
                    }
                }

            }
            .onAppear { currentCanvasSize = proxy.size; load(size: proxy.size) }
            .onChange(of: proxy.size) { _, size in currentCanvasSize = size }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active, editingCoordinator.isEditing { save(size: proxy.size) }
            }
            .onChange(of: editingCoordinator.beginToken) { _, _ in beginEditing() }
            .onChange(of: editingCoordinator.finishToken) { _, _ in saveAndFinish() }
            .onChange(of: editingCoordinator.textToken) { _, _ in showTextEntry = true }
            .onChange(of: editingCoordinator.memoryToken) { _, _ in showMemoryPicker = true }
            .onChange(of: editingCoordinator.removeToken) { _, _ in removeSelection() }
            .onChange(of: editingCoordinator.bringToFrontToken) { _, _ in bringSelectionToFront() }
        }
        .sheet(isPresented: $showMemoryPicker) {
            LockerMemoryPicker(
                excludedMemoryIDs: Set(placements.map(\.memoryID)),
                maximumSelectionCount: max(
                    0,
                    LockerCanvasRepository.maximumUserMemories
                        - placements.filter { $0.kind == .userAdded }.count
                ),
                onAdd: addMemories
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("文字を追加", isPresented: $showTextEntry) {
            TextField("ロッカーにひとこと", text: $textEntry)
            Button("キャンセル", role: .cancel) { textEntry = "" }
            Button("追加") { addText() }
        } message: { Text("30文字までの短い言葉") }
        .alert("LockU", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func lockerText(_ item: LockerTextDecoration, size: CGSize) -> some View {
        Text(item.text).font(.system(size: 18, weight: .medium, design: .rounded)).foregroundStyle(Color(lockUHex: item.colorHex ?? "#162636"))
            .shadow(color: .black.opacity(selectedTextID == item.id ? 0.12 : 0), radius: selectedTextID == item.id ? 2 : 0)
            .padding(6).overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(selectedTextID == item.id ? 0.55 : 0), lineWidth: 0.8))
            .scaleEffect(CGFloat(item.scale)).rotationEffect(.degrees(item.rotationDegrees))
            .position(x: CGFloat(item.normalizedX) * size.width, y: CGFloat(item.normalizedY) * size.height)
            .zIndex(Double(item.zIndex ?? 30))
            .onTapGesture { guard editingCoordinator.isEditing, !editingCoordinator.isDrawing else { return }; selectedTextID = item.id; selectedPlacementID = nil; editingCoordinator.selection = .text }
            .gesture(editingCoordinator.isEditing && !editingCoordinator.isDrawing ? transformGesture(textID: item.id, size: size) : nil)
            .accessibilityLabel("ロッカーの文字、\(item.text)")
    }

    private func lockerMemory(_ memory: MemoryRecord, placement: LockerMemoryPlacement, size: CGSize) -> some View {
        DownsampledLockerCanvasMemory(memory: memory)
            .frame(width: 82, height: 102).background(.white).clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 3) {
                    if let emoji = memory.moodEmoji { Text(emoji).font(.system(size: 19)) }
                    if let note = memory.memoryNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                        Text(note).font(.system(size: 7.5, weight: .medium)).lineLimit(2).foregroundStyle(LockUDesign.Color.softInk)
                    }
                }
                .padding(4).background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 4))
            }
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(selectedPlacementID == placement.id ? 0.7 : 0), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: selectedPlacementID == placement.id ? 5 : 2, y: 2)
            .scaleEffect(CGFloat(placement.scale)).rotationEffect(.degrees(placement.rotationDegrees))
            .position(x: CGFloat(placement.normalizedX) * size.width, y: CGFloat(placement.normalizedY) * size.height)
            .onTapGesture { guard editingCoordinator.isEditing, !editingCoordinator.isDrawing else { return }; selectedPlacementID = placement.id; selectedTextID = nil; editingCoordinator.selection = .memory }
            .gesture(editingCoordinator.isEditing && !editingCoordinator.isDrawing ? transformGesture(placementID: placement.id, size: size) : nil)
    }

    private func transformGesture(textID: UUID? = nil, placementID: UUID? = nil, size: CGSize) -> some Gesture {
        let base = transformValues(textID, placementID)
        return SimultaneousGesture(
            DragGesture().onChanged { value in mutate(textID, placementID) { x, y, _, _ in x = clamp(base.x + Double(value.translation.width / max(size.width, 1)), 0.08, 0.92); y = clamp(base.y + Double(value.translation.height / max(size.height, 1)), 0.08, 0.92) } },
            SimultaneousGesture(
                MagnificationGesture().onChanged { value in mutate(textID, placementID) { _, _, scale, _ in scale = clamp(base.scale * Double(value), placementID == nil ? 0.7 : 0.3, 1.5) } },
                RotationGesture().onChanged { value in mutate(textID, placementID) { _, _, _, rotation in rotation = clamp(base.rotation + value.degrees, -15, 15) } }
            )
        )
    }

    private func transformValues(_ textID: UUID?, _ placementID: UUID?) -> (x: Double, y: Double, scale: Double, rotation: Double) {
        if let textID, let item = texts.first(where: { $0.id == textID }) { return (item.normalizedX, item.normalizedY, item.scale, item.rotationDegrees) }
        if let placementID, let item = placements.first(where: { $0.id == placementID }) { return (item.normalizedX, item.normalizedY, item.scale, item.rotationDegrees) }
        return (0.5, 0.5, 1, 0)
    }

    private func mutate(_ textID: UUID?, _ placementID: UUID?, _ change: (inout Double, inout Double, inout Double, inout Double) -> Void) {
        if let textID, let index = texts.firstIndex(where: { $0.id == textID }) {
            var item = texts[index]
            var x = item.normalizedX
            var y = item.normalizedY
            var scale = item.scale
            var rotation = item.rotationDegrees
            change(&x, &y, &scale, &rotation)
            item.normalizedX = x
            item.normalizedY = y
            item.scale = scale
            item.rotationDegrees = rotation
            texts[index] = item
        }
        if let placementID, let index = placements.firstIndex(where: { $0.id == placementID }) {
            var item = placements[index]
            var x = item.normalizedX
            var y = item.normalizedY
            var scale = item.scale
            var rotation = item.rotationDegrees
            change(&x, &y, &scale, &rotation)
            item.normalizedX = x
            item.normalizedY = y
            item.scale = scale
            item.rotationDegrees = rotation
            placements[index] = item
        }
    }

    private func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double { min(max(value, low), high) }
    private func beginEditing() { snapshot = Snapshot(texts: texts, placements: placements, drawing: drawing) }
    private func saveAndFinish() { save(size: currentCanvasSize); selectedTextID = nil; selectedPlacementID = nil }
    private func removeSelection() {
        if let selectedTextID { texts.removeAll { $0.id == selectedTextID }; self.selectedTextID = nil }
        if let selectedPlacementID { placements.removeAll { $0.id == selectedPlacementID }; self.selectedPlacementID = nil }
    }
    private func bringSelectionToFront() {
        guard let selectedPlacementID,
              let index = placements.firstIndex(where: { $0.id == selectedPlacementID }) else { return }
        placements[index].zIndex = (placements.map(\.zIndex).max() ?? placements[index].zIndex) + 1
    }
    private func save(size: CGSize) { do { try canvasRepository.commit(texts: texts, placements: placements, drawingData: drawing.dataRepresentation(), drawingSize: size == .zero ? nil : size) } catch { errorMessage = error.localizedDescription } }
    private func load(size: CGSize) {
        texts = canvasRepository.metadata.texts
        placements = canvasRepository.metadata.memoryPlacements
        let reference = CGSize(width: CGFloat(canvasRepository.metadata.drawingReferenceWidth ?? Double(size.width)), height: CGFloat(canvasRepository.metadata.drawingReferenceHeight ?? Double(size.height)))
        if let data = canvasRepository.drawingData(), var loaded = try? PKDrawing(data: data) {
            if reference.width > 0, reference.height > 0, reference != size {
                loaded = loaded.transformed(using: CGAffineTransform(scaleX: size.width / reference.width, y: size.height / reference.height))
            }
            drawing = loaded
        }
        drawingSize = size
    }
    private func addText() {
        let normalized = String(textEntry.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        guard !normalized.isEmpty else { return }
        texts.append(LockerTextDecoration(
            id: UUID(), text: normalized,
            normalizedX: 0.5, normalizedY: 0.68,
            scale: 1, rotationDegrees: 0,
            colorHex: "#162636",
            zIndex: (texts.compactMap(\.zIndex).max() ?? 29) + 1,
            createdAt: .now
        ))
        textEntry = ""
    }
    private func addMemories(_ memories: [MemoryRecord]) {
        let existingIDs = Set(placements.map(\.memoryID))
        let remainingCount = max(0, LockerCanvasRepository.maximumUserMemories - placements.filter { $0.kind == .userAdded }.count)
        let additions = memories.filter { !existingIDs.contains($0.id) }.prefix(remainingCount)
        guard !additions.isEmpty else { return }

        let startingZIndex = placements.map(\.zIndex).max() ?? 40
        let initialPositions: [(Double, Double)] = [
            (0.56, 0.48), (0.72, 0.38), (0.36, 0.60), (0.66, 0.66),
            (0.30, 0.38), (0.50, 0.72), (0.76, 0.56), (0.42, 0.44),
            (0.58, 0.32), (0.34, 0.70)
        ]
        for (index, memory) in additions.enumerated() {
            let position = initialPositions[index % initialPositions.count]
            placements.append(LockerMemoryPlacement(
                id: UUID(), memoryID: memory.id,
                normalizedX: position.0, normalizedY: position.1,
                scale: 1, rotationDegrees: 0,
                zIndex: startingZIndex + index + 1,
                kind: .userAdded, createdAt: .now
            ))
        }
        showMemoryPicker = false
    }
    private struct Snapshot { let texts: [LockerTextDecoration]; let placements: [LockerMemoryPlacement]; let drawing: PKDrawing }
}

private struct LockerPencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let canvasSize: CGSize
    let referenceSize: CGSize
    let isDrawingEnabled: Bool
    let color: UIColor
    let width: CGFloat
    let isEraser: Bool

    func makeCoordinator() -> Coordinator { Coordinator(drawing: $drawing) }
    func makeUIView(context: Context) -> PKCanvasView { let view = PKCanvasView(); view.backgroundColor = .clear; view.isOpaque = false; view.delegate = context.coordinator; view.drawingPolicy = .anyInput; context.coordinator.canvas = view; context.coordinator.undoObserver = NotificationCenter.default.addObserver(forName: .lockerCanvasUndo, object: nil, queue: .main) { [weak view] _ in view?.undoManager?.undo() }; return view }
    func updateUIView(_ view: PKCanvasView, context: Context) {
        view.isUserInteractionEnabled = isDrawingEnabled
        view.tool = isEraser ? PKEraserTool(.vector) : PKInkingTool(.pen, color: color, width: width)
        if view.drawing != drawing {
            var resolved = drawing
            if referenceSize.width > 0, referenceSize.height > 0, canvasSize != referenceSize { resolved = drawing.transformed(using: CGAffineTransform(scaleX: canvasSize.width / referenceSize.width, y: canvasSize.height / referenceSize.height)) }
            context.coordinator.isApplyingDrawing = true
            view.drawing = resolved
            context.coordinator.isApplyingDrawing = false
        }
    }
    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) { if let observer = coordinator.undoObserver { NotificationCenter.default.removeObserver(observer) }; coordinator.undoObserver = nil; coordinator.canvas = nil }
    final class Coordinator: NSObject, PKCanvasViewDelegate { @Binding var drawing: PKDrawing; weak var canvas: PKCanvasView?; var undoObserver: NSObjectProtocol?; var isApplyingDrawing = false; init(drawing: Binding<PKDrawing>) { _drawing = drawing }; func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { guard !isApplyingDrawing else { return }; drawing = canvasView.drawing } }
}

private extension Notification.Name { static let lockerCanvasUndo = Notification.Name("LockU.LockerCanvas.Undo") }

private struct LockerMemoryPicker: View {
    @EnvironmentObject private var repository: MemoryRepository
    @Environment(\.dismiss) private var dismiss
    let excludedMemoryIDs: Set<UUID>
    let maximumSelectionCount: Int
    let onAdd: ([MemoryRecord]) -> Void
    @State private var selectedIDs: Set<UUID> = []
    @State private var filter: Filter = .all
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "すべて"
        case date = "日付"
        var id: Self { self }
    }

    private var availableMemories: [MemoryRecord] {
        let memories = repository.memories.filter { !excludedMemoryIDs.contains($0.id) }
        switch filter {
        case .all:
            return memories.sorted { $0.createdAt > $1.createdAt }
        case .date:
            return memories.sorted { $0.memoryDate > $1.memoryDate }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("表示", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(availableMemories) { memory in
                            memoryButton(memory)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }

                HStack {
                    Button("キャンセル") { dismiss() }
                    Spacer()
                    Button("追加（\(selectedIDs.count)）") {
                        let selected = availableMemories.filter { selectedIDs.contains($0.id) }
                        onAdd(selected)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LockUDesign.Color.schoolNavy)
                    .disabled(selectedIDs.isEmpty)
                }
                .padding(16)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("思い出を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func memoryButton(_ memory: MemoryRecord) -> some View {
        let isSelected = selectedIDs.contains(memory.id)
        return Button {
            if isSelected {
                selectedIDs.remove(memory.id)
            } else if selectedIDs.count < maximumSelectionCount {
                selectedIDs.insert(memory.id)
            }
        } label: {
            VStack(spacing: 4) {
                DownsampledLockerCanvasMemory(memory: memory)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .overlay(alignment: .bottomTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(5)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                    }
                Text(memory.memoryDate.formatted(.dateTime.month().day()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isSelected && selectedIDs.count >= maximumSelectionCount)
        .accessibilityLabel("\(memory.memoryDate.formatted(.dateTime.month().day()))の思い出")
        .accessibilityValue(isSelected ? "選択中" : "未選択")
    }
}

private struct DownsampledLockerCanvasMemory: View {
    @EnvironmentObject private var repository: MemoryRepository
    @State private var image: UIImage?
    let memory: MemoryRecord
    var body: some View { Group { if let image { Image(uiImage: image).resizable().scaledToFill() } else { Color.gray.opacity(0.35).overlay(ProgressView()) } }.task(id: memory.id) { image = await repository.imageAsync(for: memory, purpose: .locker, targetPointSize: CGSize(width: 150, height: 180)) }.onDisappear { image = nil } }
}
