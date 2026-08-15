import PencilKit
import SwiftUI

@MainActor
final class LockerCanvasEditingCoordinator: ObservableObject {
    enum Mode: String { case inactive, editing, drawing }
    enum Selection { case none, text, drawing, memory }
    @Published private(set) var isEditing = false
    @Published var isDrawing = false
    @Published var erasing = false
    @Published var penColor = UIColor(red: 0.06, green: 0.12, blue: 0.22, alpha: 1)
    @Published var penWidth: CGFloat = 3
    @Published private(set) var beginToken = 0
    @Published private(set) var finishToken = 0
    @Published private(set) var textToken = 0
    @Published private(set) var memoryToken = 0
    @Published private(set) var removeToken = 0
    @Published private(set) var bringToFrontToken = 0
    @Published private(set) var fontToken = 0
    @Published private(set) var colorToken = 0
    @Published private(set) var contentToken = 0
    @Published private(set) var undoEditToken = 0
    @Published private(set) var duplicateToken = 0
    @Published var selectedFontStyle: LockerTextFontStyle = .handwritten
    @Published var selectedColorStyle: LockerTextColorStyle = .charcoal
    @Published var selectedTextPreview = "放課後"
    @Published var selection: Selection = .none

    var mode: Mode {
        if !isEditing { return .inactive }
        return isDrawing ? .drawing : .editing
    }

    func begin() { guard !isEditing else { return }; isEditing = true; beginToken &+= 1 }
    func finish() { guard isEditing else { return }; finishToken &+= 1; isEditing = false; isDrawing = false; selection = .none }
    func toggleDrawing() { guard isEditing else { return }; isDrawing.toggle(); selection = .none }
    func requestText() { guard isEditing else { return }; isDrawing = false; selection = .none; textToken &+= 1 }
    func requestMemory() { guard isEditing else { return }; isDrawing = false; selection = .none; memoryToken &+= 1 }
    func removeSelection() { guard selection != .none else { return }; removeToken &+= 1; selection = .none }
    func bringSelectionToFront() { guard selection == .memory else { return }; bringToFrontToken &+= 1 }
    func selectText(text: String, font: LockerTextFontStyle, color: LockerTextColorStyle) {
        selectedTextPreview = text
        selectedFontStyle = font
        selectedColorStyle = color
        selection = .text
    }
    func changeFont(to style: LockerTextFontStyle) { selectedFontStyle = style; fontToken &+= 1 }
    func changeColor(to style: LockerTextColorStyle) { selectedColorStyle = style; colorToken &+= 1 }
    func requestTextContentEdit() { guard selection == .text else { return }; contentToken &+= 1 }
    func duplicateSelection() { guard selection == .text || selection == .drawing else { return }; duplicateToken &+= 1 }
    func undoEdit() { undoEditToken &+= 1 }
    func undoDrawing() { NotificationCenter.default.post(name: .lockerCanvasUndo, object: nil) }
}

private enum LockerEditorSelection: Equatable {
    case drawing(UUID)
    case text(UUID)
    case memory(UUID)
}

struct LockerCanvasLayer: View {
    @EnvironmentObject private var canvasRepository: LockerCanvasRepository
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @EnvironmentObject private var editingCoordinator: LockerCanvasEditingCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var texts: [LockerTextDecoration] = []
    @State private var placements: [LockerMemoryPlacement] = []
    @State private var drawingDecorations: [LockerDrawingDecoration] = []
    @State private var selection: LockerEditorSelection?
    @State private var drawing = PKDrawing()
    @State private var pencilSessionStartStrokeCount = 0
    @State private var drawingSize: CGSize = .zero
    @State private var currentCanvasSize: CGSize = .zero
    @State private var showTextEntry = false
    @State private var textEntry = ""
    @State private var editingTextID: UUID?
    @State private var showMemoryPicker = false
    @State private var errorMessage: String?
    @State private var undoStack: [EditorUndoSnapshot] = []

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard editingCoordinator.isEditing, !editingCoordinator.isDrawing else { return }
                        selection = nil
                        editingCoordinator.selection = .none
                    }
                    .allowsHitTesting(editingCoordinator.isEditing && !editingCoordinator.isDrawing)
                    .zIndex(-1)

                ForEach(drawingDecorations.sorted { $0.zIndex < $1.zIndex }) { decoration in
                    LockerDrawingItemView(
                        decoration: binding(forDrawingID: decoration.id, fallback: decoration),
                        canvasSize: proxy.size,
                        isEditing: editingCoordinator.isEditing && !editingCoordinator.isDrawing,
                        isSelected: selection == .drawing(decoration.id),
                        onSelect: { selectDrawing(decoration.id) },
                        onWillChange: pushUndo,
                        onCommit: { save(size: proxy.size) }
                    )
                    .zIndex(selection == .drawing(decoration.id) ? 1_500 : Double(decoration.zIndex))
                }

                LockerPencilCanvas(
                    drawing: $drawing, canvasSize: proxy.size, referenceSize: drawingSize,
                    isDrawingEnabled: editingCoordinator.isEditing && editingCoordinator.isDrawing,
                    color: editingCoordinator.penColor,
                    width: editingCoordinator.penWidth,
                    isEraser: editingCoordinator.erasing
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .opacity(editingCoordinator.isEditing && editingCoordinator.isDrawing ? 1 : 0.46)
                .allowsHitTesting(editingCoordinator.isEditing && editingCoordinator.isDrawing)
                .zIndex(editingCoordinator.isEditing && editingCoordinator.isDrawing ? 2_000 : 0)

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
                if phase != .active, editingCoordinator.isEditing {
                    if editingCoordinator.isDrawing { finalizePencilSession(size: proxy.size) }
                    save(size: proxy.size)
                }
            }
            .onChange(of: editingCoordinator.beginToken) { _, _ in beginEditing() }
            .onChange(of: editingCoordinator.finishToken) { _, _ in saveAndFinish() }
            .onChange(of: editingCoordinator.isDrawing) { wasDrawing, isDrawing in
                #if DEBUG
                print(isDrawing ? "[LockerPencil][MODE_ENTER]" : "[LockerPencil][MODE_EXIT]")
                #endif
                if wasDrawing && !isDrawing {
                    finalizePencilSession(size: proxy.size)
                    save(size: proxy.size)
                } else if isDrawing {
                    pencilSessionStartStrokeCount = drawing.strokes.count
                    selection = nil
                }
            }
            .onChange(of: editingCoordinator.textToken) { _, _ in
                editingTextID = nil
                textEntry = ""
                showTextEntry = true
            }
            .onChange(of: editingCoordinator.contentToken) { _, _ in beginSelectedTextContentEdit() }
            .onChange(of: editingCoordinator.memoryToken) { _, _ in showMemoryPicker = true }
            .onChange(of: editingCoordinator.removeToken) { _, _ in removeSelection() }
            .onChange(of: editingCoordinator.bringToFrontToken) { _, _ in bringSelectionToFront() }
            .onChange(of: editingCoordinator.fontToken) { _, _ in changeSelectedTextFont() }
            .onChange(of: editingCoordinator.colorToken) { _, _ in changeSelectedTextColor() }
            .onChange(of: editingCoordinator.undoEditToken) { _, _ in undoLastEdit() }
            .onChange(of: editingCoordinator.duplicateToken) { _, _ in duplicateSelection() }
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
        .alert(editingTextID == nil ? "文字を追加" : "文字の内容", isPresented: $showTextEntry) {
            TextField("ロッカーにひとこと", text: $textEntry)
            Button("キャンセル", role: .cancel) { textEntry = ""; editingTextID = nil }
            Button(editingTextID == nil ? "追加" : "保存") { commitTextEntry() }
        } message: { Text("30文字までの短い言葉") }
        .onChange(of: textEntry) { _, value in
            if value.count > 30 { textEntry = String(value.prefix(30)) }
        }
        .alert("LockU", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func lockerText(_ item: LockerTextDecoration, size: CGSize) -> some View {
        LockerTextItemView(
            item: binding(forTextID: item.id, fallback: item), canvasSize: size,
            isEditing: editingCoordinator.isEditing && !editingCoordinator.isDrawing,
            isSelected: selection == .text(item.id),
            onSelect: { selectText(item.id) },
            onWillChange: pushUndo,
            onCommit: { save(size: size) }
        )
        .zIndex(1_000 + Double(item.zIndex))
    }

    private func binding(forTextID id: UUID, fallback: LockerTextDecoration) -> Binding<LockerTextDecoration> {
        Binding(
            get: { texts.first(where: { $0.id == id }) ?? fallback },
            set: { updated in
                guard let index = texts.firstIndex(where: { $0.id == id }) else { return }
                texts[index] = updated
            }
        )
    }

    private func selectText(_ id: UUID) {
        guard let index = texts.firstIndex(where: { $0.id == id }) else { return }
        selection = .text(id)
        editingCoordinator.selectText(text: texts[index].text, font: texts[index].fontStyle, color: texts[index].colorStyle)
        #if DEBUG
        print("[LockerEditor][SELECTION] text id=\(id.uuidString)")
        #endif
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45)
    }

    private func binding(forDrawingID id: UUID, fallback: LockerDrawingDecoration) -> Binding<LockerDrawingDecoration> {
        Binding(
            get: { drawingDecorations.first(where: { $0.id == id }) ?? fallback },
            set: { updated in
                guard let index = drawingDecorations.firstIndex(where: { $0.id == id }) else { return }
                drawingDecorations[index] = updated
            }
        )
    }

    private func selectDrawing(_ id: UUID) {
        guard drawingDecorations.contains(where: { $0.id == id }) else { return }
        selection = .drawing(id)
        editingCoordinator.selection = .drawing
        #if DEBUG
        print("[LockerEditor][SELECTION] drawing id=\(id.uuidString)")
        #endif
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45)
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
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(selection == .memory(placement.id) ? 0.7 : 0), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: selection == .memory(placement.id) ? 5 : 2, y: 2)
            .scaleEffect(CGFloat(placement.scale)).rotationEffect(.degrees(placement.rotationDegrees))
            .position(x: CGFloat(placement.normalizedX) * size.width, y: CGFloat(placement.normalizedY) * size.height)
            .zIndex(100 + Double(placement.zIndex))
            .onTapGesture { guard editingCoordinator.isEditing, !editingCoordinator.isDrawing else { return }; selection = .memory(placement.id); editingCoordinator.selection = .memory }
            .gesture(editingCoordinator.isEditing && !editingCoordinator.isDrawing ? transformGesture(placementID: placement.id, size: size) : nil)
            .allowsHitTesting(!editingCoordinator.isEditing)
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
    private func beginEditing() { selection = nil; undoStack.removeAll() }
    private func saveAndFinish() {
        if editingCoordinator.isDrawing { finalizePencilSession(size: currentCanvasSize) }
        save(size: currentCanvasSize)
        selection = nil
        undoStack.removeAll()
    }
    private func removeSelection() {
        guard let selection else { return }
        pushUndo()
        switch selection {
        case .text(let id): texts.removeAll { $0.id == id }
        case .drawing(let id): drawingDecorations.removeAll { $0.id == id }
        case .memory(let id): placements.removeAll { $0.id == id }
        }
        self.selection = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.55)
        save(size: currentCanvasSize)
    }
    private func changeSelectedTextFont() {
        guard case .text(let id) = selection, let index = texts.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        texts[index].fontStyle = editingCoordinator.selectedFontStyle
        texts[index] = texts[index].clamped(to: currentCanvasSize)
        save(size: currentCanvasSize)
    }
    private func changeSelectedTextColor() {
        guard case .text(let id) = selection, let index = texts.firstIndex(where: { $0.id == id }) else { return }
        pushUndo()
        texts[index].colorStyle = editingCoordinator.selectedColorStyle
        save(size: currentCanvasSize)
    }
    private func beginSelectedTextContentEdit() {
        guard case .text(let id) = selection,
              let item = texts.first(where: { $0.id == id }) else { return }
        editingTextID = id
        textEntry = item.text
        showTextEntry = true
    }
    private func bringSelectionToFront() {
        guard case .memory(let id) = selection,
              let index = placements.firstIndex(where: { $0.id == id }) else { return }
        placements[index].zIndex = (placements.map(\.zIndex).max() ?? placements[index].zIndex) + 1
    }
    private func save(size: CGSize) { do { try canvasRepository.commit(texts: texts, placements: placements, drawingDecorations: drawingDecorations, drawingData: drawing.dataRepresentation(), drawingSize: size == .zero ? nil : size) } catch { errorMessage = error.localizedDescription } }
    private func load(size: CGSize) {
        texts = canvasRepository.metadata.texts
        placements = canvasRepository.metadata.memoryPlacements
        drawingDecorations = canvasRepository.metadata.drawingDecorations
        let reference = CGSize(width: CGFloat(canvasRepository.metadata.drawingReferenceWidth ?? Double(size.width)), height: CGFloat(canvasRepository.metadata.drawingReferenceHeight ?? Double(size.height)))
        if let data = canvasRepository.drawingData(), var loaded = try? PKDrawing(data: data) {
            if reference.width > 0, reference.height > 0, reference != size {
                loaded = loaded.transformed(using: CGAffineTransform(scaleX: size.width / reference.width, y: size.height / reference.height))
            }
            drawing = loaded
        }
        drawingSize = size
    }
    private func finalizePencilSession(size: CGSize) {
        guard size.width > 0, size.height > 0,
              drawing.strokes.count > pencilSessionStartStrokeCount else { return }
        let sessionStrokes = Array(drawing.strokes.dropFirst(pencilSessionStartStrokeCount))
        let converted: [LockerDrawingStroke] = sessionStrokes.compactMap { stroke in
            let points = stroke.path.map { point in
                CodablePoint(
                    x: Double(point.location.x / size.width),
                    y: Double(point.location.y / size.height)
                )
            }
            guard !points.isEmpty else { return nil }
            let widths = stroke.path.map { Double($0.size.width) }
            return LockerDrawingStroke(
                id: UUID(), points: points,
                colorStyle: drawingColorStyle(for: stroke.ink.color),
                lineWidth: max(1, widths.reduce(0, +) / Double(max(widths.count, 1)))
            )
        }
        let allPoints = converted.flatMap(\.points)
        guard !converted.isEmpty,
              let minX = allPoints.map(\.x).min(), let maxX = allPoints.map(\.x).max(),
              let minY = allPoints.map(\.y).min(), let maxY = allPoints.map(\.y).max() else { return }

        let center = CodablePoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let localStrokes = converted.map { stroke in
            var local = stroke
            local.points = stroke.points.map { CodablePoint(x: $0.x - center.x, y: $0.y - center.y) }
            return local
        }
        pushUndo()
        let decoration = LockerDrawingDecoration(
            id: UUID(), strokes: localStrokes, position: center,
            scale: 1, rotationDegrees: 0,
            zIndex: (drawingDecorations.map(\.zIndex).max() ?? 9) + 1,
            createdAt: .now
        )
        drawingDecorations.append(decoration)
        drawing = PKDrawing(strokes: Array(drawing.strokes.prefix(pencilSessionStartStrokeCount)))
        drawingSize = size
        pencilSessionStartStrokeCount = drawing.strokes.count
        selectDrawing(decoration.id)
    }

    private func drawingColorStyle(for color: UIColor) -> LockerDrawingColorStyle {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return .navy }
        if red > 0.8, green > 0.8, blue > 0.8 { return .white }
        if red > 0.75, green < 0.55 { return .pink }
        if red > 0.7, green > 0.55, blue < 0.35 { return .yellow }
        if blue > red * 1.35, blue > green * 1.1 { return .blue }
        if red < 0.12, green < 0.12, blue < 0.12 { return .charcoal }
        return .navy
    }
    private func commitTextEntry() {
        let normalized = String(textEntry.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        guard !normalized.isEmpty else { return }
        if let editingTextID,
           let index = texts.firstIndex(where: { $0.id == editingTextID }) {
            pushUndo()
            texts[index].text = normalized
            editingCoordinator.selectedTextPreview = normalized
            texts[index] = texts[index].clamped(to: currentCanvasSize)
            self.editingTextID = nil
            textEntry = ""
            save(size: currentCanvasSize)
            return
        }
        let newText = LockerTextDecoration(
            id: UUID(), text: normalized,
            normalizedX: 0.5, normalizedY: 0.65,
            scale: 1, rotationDegrees: 0,
            zIndex: (texts.map(\.zIndex).max() ?? 29) + 1,
            fontStyle: .handwritten, colorStyle: .charcoal,
            createdAt: .now
        )
        pushUndo()
        texts.append(newText)
        textEntry = ""
        editingTextID = nil
        selectText(newText.id)
        save(size: currentCanvasSize)
    }
    private func duplicateSelection() {
        let offsetX = 20 / max(Double(currentCanvasSize.width), 1)
        let offsetY = 20 / max(Double(currentCanvasSize.height), 1)
        switch selection {
        case .text(let id):
            guard let source = texts.first(where: { $0.id == id }) else { return }
            pushUndo()
            let copy = LockerTextDecoration(
                id: UUID(), text: source.text,
                normalizedX: min(source.normalizedX + offsetX, 0.94),
                normalizedY: min(source.normalizedY + offsetY, 0.94),
                scale: source.scale, rotationDegrees: source.rotationDegrees,
                zIndex: (texts.map(\.zIndex).max() ?? source.zIndex) + 1,
                fontStyle: source.fontStyle, colorStyle: source.colorStyle,
                createdAt: .now
            ).clamped(to: currentCanvasSize)
            texts.append(copy)
            selectText(copy.id)
        case .drawing(let id):
            guard let source = drawingDecorations.first(where: { $0.id == id }) else { return }
            pushUndo()
            let copy = LockerDrawingDecoration(
                id: UUID(), strokes: source.strokes,
                position: CodablePoint(
                    x: min(source.position.x + offsetX, 0.94),
                    y: min(source.position.y + offsetY, 0.94)
                ),
                scale: source.scale, rotationDegrees: source.rotationDegrees,
                zIndex: (drawingDecorations.map(\.zIndex).max() ?? source.zIndex) + 1,
                createdAt: .now
            )
            drawingDecorations.append(copy)
            selectDrawing(copy.id)
        default: return
        }
        save(size: currentCanvasSize)
    }

    private func pushUndo() {
        undoStack.append(EditorUndoSnapshot(texts: texts, drawings: drawingDecorations, selection: selection))
        if undoStack.count > 10 { undoStack.removeFirst(undoStack.count - 10) }
    }

    private func undoLastEdit() {
        guard let snapshot = undoStack.popLast() else { return }
        texts = snapshot.texts
        drawingDecorations = snapshot.drawings
        selection = snapshot.selection
        switch selection {
        case .text(let id):
            if let item = texts.first(where: { $0.id == id }) {
                editingCoordinator.selectText(text: item.text, font: item.fontStyle, color: item.colorStyle)
            } else { editingCoordinator.selection = .none }
        case .drawing: editingCoordinator.selection = .drawing
        default: editingCoordinator.selection = .none
        }
        save(size: currentCanvasSize)
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
    private struct EditorUndoSnapshot {
        let texts: [LockerTextDecoration]
        let drawings: [LockerDrawingDecoration]
        let selection: LockerEditorSelection?
    }

}

private struct LockerTextItemView: View {
    @Binding var item: LockerTextDecoration
    let canvasSize: CGSize
    let isEditing: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onWillChange: () -> Void
    let onCommit: () -> Void

    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var rotation: Angle = .zero
    @State private var isDragging = false

    var body: some View {
        Text(item.text)
            .font(LockerTextFontResolver.font(for: item.fontStyle, size: 20))
            .foregroundStyle(LockerTextColorResolver.color(for: item.colorStyle))
            .fixedSize()
            .shadow(
                color: item.colorStyle == .white ? .black.opacity(0.08) : .clear,
                radius: 1, y: 1
            )
            .padding(6)
            .frame(minWidth: 44, minHeight: 44)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.white.opacity(isEditing && isSelected ? 0.48 : 0), lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
            .scaleEffect(CGFloat(item.scale) * magnification)
            .rotationEffect(.degrees(item.rotationDegrees) + rotation)
            .position(
                x: CGFloat(item.normalizedX) * canvasSize.width + dragTranslation.width,
                y: CGFloat(item.normalizedY) * canvasSize.height + dragTranslation.height
            )
            .contentShape(Rectangle())
            .simultaneousGesture(
                isEditing ? TapGesture().onEnded {
                    debugLog("[LockerEditor][TEXT_HIT] id=\(item.id.uuidString)")
                    onSelect()
                } : nil
            )
            .gesture(isEditing ? gestures : nil)
            .allowsHitTesting(isEditing)
            .accessibilityLabel("ロッカーテキスト、\(item.text)")
            .accessibilityHint(isEditing ? "移動、フォント変更、色変更、削除ができます" : "")
            .accessibilityAction(named: "選択") { if isEditing { onSelect() } }
    }

    private var gestures: some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($dragTranslation) { value, state, _ in state = value.translation }
            .onChanged { _ in
                guard !isDragging else { return }
                isDragging = true
                onSelect()
                debugLog("[LockerEditor][TEXT_DRAG_BEGIN] id=\(item.id.uuidString)")
            }
            .onEnded { value in
                onWillChange()
                item.normalizedX += Double(value.translation.width / max(canvasSize.width, 1))
                item.normalizedY += Double(value.translation.height / max(canvasSize.height, 1))
                item = item.clamped(to: canvasSize)
                onCommit()
                isDragging = false
                debugLog("[LockerEditor][TEXT_DRAG_END] id=\(item.id.uuidString)")
            }
            .simultaneously(with:
                MagnificationGesture()
                    .updating($magnification) { value, state, _ in state = value }
                    .onEnded { value in
                        onWillChange()
                        item.scale = min(max(item.scale * Double(value), 0.65), 1.8)
                        item = item.clamped(to: canvasSize)
                        onCommit()
                    }
            )
            .simultaneously(with:
                RotationGesture()
                    .updating($rotation) { value, state, _ in state = value }
                    .onEnded { value in
                        onWillChange()
                        let proposed = min(max(item.rotationDegrees + value.degrees, -25), 25)
                        item.rotationDegrees = abs(proposed) <= 2 ? 0 : proposed
                        if item.rotationDegrees == 0 {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.35)
                        }
                        item = item.clamped(to: canvasSize)
                        onCommit()
                    }
            )
    }

    private func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        print(message())
        #endif
    }
}

private struct LockerDrawingItemView: View {
    @Binding var decoration: LockerDrawingDecoration
    let canvasSize: CGSize
    let isEditing: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onWillChange: () -> Void
    let onCommit: () -> Void
    @GestureState private var translation: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var rotation: Angle = .zero
    @State private var isDragging = false

    private var drawingSize: CGSize {
        let points = decoration.strokes.flatMap(\.points)
        let width = (points.map(\.x).max() ?? 0) - (points.map(\.x).min() ?? 0)
        let height = (points.map(\.y).max() ?? 0) - (points.map(\.y).min() ?? 0)
        return CGSize(width: max(44, width * canvasSize.width + 32), height: max(44, height * canvasSize.height + 32))
    }

    var body: some View {
        Canvas { context, size in
            for stroke in decoration.strokes {
                guard let first = stroke.points.first else { continue }
                var path = Path()
                path.move(to: localPoint(first, size: size))
                for point in stroke.points.dropFirst() { path.addLine(to: localPoint(point, size: size)) }
                context.stroke(path, with: .color(stroke.colorStyle.color), style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: drawingSize.width, height: drawingSize.height)
        .contentShape(Rectangle())
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(.white.opacity(isEditing && isSelected ? 0.5 : 0), style: StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
                .allowsHitTesting(false)
        }
        .scaleEffect(CGFloat(decoration.scale) * magnification)
        .rotationEffect(.degrees(decoration.rotationDegrees) + rotation)
        .position(
            x: CGFloat(decoration.position.x) * canvasSize.width + translation.width,
            y: CGFloat(decoration.position.y) * canvasSize.height + translation.height
        )
        .simultaneousGesture(
            isEditing ? TapGesture().onEnded {
                debugLog("[LockerEditor][DRAWING_HIT] id=\(decoration.id.uuidString)")
                onSelect()
            } : nil
        )
        .gesture(isEditing ? gestures : nil)
        .allowsHitTesting(isEditing)
        .accessibilityLabel("ロッカーの落書き")
    }

    private func localPoint(_ point: CodablePoint, size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2 + CGFloat(point.x) * canvasSize.width, y: size.height / 2 + CGFloat(point.y) * canvasSize.height)
    }

    private var gestures: some Gesture {
        DragGesture(minimumDistance: 1)
            .updating($translation) { value, state, _ in state = value.translation }
            .onChanged { _ in
                guard !isDragging else { return }
                isDragging = true
                onSelect()
                debugLog("[LockerEditor][DRAWING_DRAG_BEGIN] id=\(decoration.id.uuidString)")
            }
            .onEnded { value in
                onWillChange()
                decoration.position.x += Double(value.translation.width / max(canvasSize.width, 1))
                decoration.position.y += Double(value.translation.height / max(canvasSize.height, 1))
                clampPosition()
                onCommit()
                isDragging = false
                debugLog("[LockerEditor][DRAWING_DRAG_END] id=\(decoration.id.uuidString)")
            }
            .simultaneously(with:
                MagnificationGesture()
                    .updating($magnification) { value, state, _ in state = value }
                    .onEnded { value in
                        onWillChange()
                        decoration.scale = min(max(decoration.scale * Double(value), 0.6), 1.8)
                        clampPosition()
                        onCommit()
                    }
            )
            .simultaneously(with:
                RotationGesture()
                    .updating($rotation) { value, state, _ in state = value }
                    .onEnded { value in
                        onWillChange()
                        let proposed = min(max(decoration.rotationDegrees + value.degrees, -30), 30)
                        decoration.rotationDegrees = abs(proposed) <= 2 ? 0 : proposed
                        if decoration.rotationDegrees == 0 {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.35)
                        }
                        onCommit()
                    }
            )
    }

    private func clampPosition() {
        let visibleX = min(0.49, Double(drawingSize.width * CGFloat(decoration.scale) * 0.35 / max(canvasSize.width, 1)))
        let visibleY = min(0.49, Double(drawingSize.height * CGFloat(decoration.scale) * 0.35 / max(canvasSize.height, 1)))
        decoration.position.x = min(max(decoration.position.x, visibleX), 1 - visibleX)
        decoration.position.y = min(max(decoration.position.y, visibleY), 1 - visibleY)
    }

    private func debugLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        print(message())
        #endif
    }
}

private extension LockerDrawingColorStyle {
    var color: Color {
        switch self {
        case .charcoal: Color(lockUHex: "#34383C")
        case .navy: Color(lockUHex: "#162636")
        case .blue: Color(lockUHex: "#3987C9")
        case .pink: Color(lockUHex: "#E985A5")
        case .white: .white
        case .yellow: Color(lockUHex: "#F2C94C")
        }
    }
}

enum LockerTextFontResolver {
    static func font(for style: LockerTextFontStyle, size: CGFloat) -> Font {
        switch style {
        case .handwritten:
            if let font = UIFont(name: "MarkerFelt-Thin", size: size) { return Font(font) }
            return .system(size: size, design: .rounded)
        case .casual:
            return .system(size: size, weight: .medium, design: .rounded)
        case .clean:
            return .system(size: size, weight: .medium, design: .default)
        case .mono:
            return .system(size: size - 1, weight: .medium, design: .monospaced)
        }
    }

    static func uiFont(for style: LockerTextFontStyle, size: CGFloat) -> UIFont {
        switch style {
        case .handwritten:
            return UIFont(name: "MarkerFelt-Thin", size: size)
                ?? UIFont.systemFont(ofSize: size, weight: .medium)
        case .casual:
            let base = UIFont.systemFont(ofSize: size, weight: .medium)
            guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
            return UIFont(descriptor: descriptor, size: size)
        case .clean: return UIFont.systemFont(ofSize: size, weight: .medium)
        case .mono: return UIFont.monospacedSystemFont(ofSize: size - 1, weight: .medium)
        }
    }
}

private enum LockerTextColorResolver {
    static func color(for style: LockerTextColorStyle) -> Color {
        switch style {
        case .charcoal: Color(lockUHex: "#34383C")
        case .navy: Color(lockUHex: "#162636")
        case .blue: Color(lockUHex: "#3987C9")
        case .pink: Color(lockUHex: "#E985A5")
        case .white: .white
        case .yellow: Color(lockUHex: "#F2C94C")
        }
    }
}

private extension LockerTextDecoration {
    func clamped(to canvasSize: CGSize) -> Self {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return self }
        var result = self
        let font = LockerTextFontResolver.uiFont(for: fontStyle, size: 20)
        let measured = (text as NSString).size(withAttributes: [.font: font])
        // Keep at least 65% of the decoration visible, including its interaction padding.
        let halfVisibleWidth = min(canvasSize.width * 0.49, (measured.width + 12) * CGFloat(scale) * 0.325)
        let halfVisibleHeight = min(canvasSize.height * 0.49, (measured.height + 12) * CGFloat(scale) * 0.325)
        result.normalizedX = min(max(normalizedX, Double(halfVisibleWidth / canvasSize.width)), Double(1 - halfVisibleWidth / canvasSize.width))
        result.normalizedY = min(max(normalizedY, Double(halfVisibleHeight / canvasSize.height)), Double(1 - halfVisibleHeight / canvasSize.height))
        return result
    }
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
    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = true
        view.drawingPolicy = .anyInput
        view.drawingGestureRecognizer.isEnabled = true
        view.drawingGestureRecognizer.cancelsTouchesInView = true
        view.tool = PKInkingTool(
            .pen,
            color: UIColor(red: 0.06, green: 0.12, blue: 0.22, alpha: 1),
            width: 3
        )
        view.delegate = context.coordinator
        context.coordinator.canvas = view
        context.coordinator.undoObserver = NotificationCenter.default.addObserver(
            forName: .lockerCanvasUndo,
            object: nil,
            queue: .main
        ) { [weak view] _ in
            view?.undoManager?.undo()
        }
        #if DEBUG
        print("[LockerPencil][CANVAS_CREATED]")
        #endif
        return view
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        view.isUserInteractionEnabled = isDrawingEnabled
        view.drawingPolicy = .anyInput
        view.drawingGestureRecognizer.isEnabled = isDrawingEnabled
        view.tool = isEraser ? PKEraserTool(.vector) : PKInkingTool(.pen, color: color, width: width)

        if context.coordinator.lastInteractionEnabled != isDrawingEnabled {
            context.coordinator.lastInteractionEnabled = isDrawingEnabled
            #if DEBUG
            print("[LockerPencil][INTERACTION] enabled=\(isDrawingEnabled) recognizer=\(view.drawingGestureRecognizer.isEnabled) policy=anyInput")
            #endif
        }

        let renderedSize = view.bounds.size == .zero ? canvasSize : view.bounds.size
        if context.coordinator.lastLoggedSize != renderedSize {
            context.coordinator.lastLoggedSize = renderedSize
            #if DEBUG
            print("[LockerPencil][CANVAS_FRAME] width=\(renderedSize.width) height=\(renderedSize.height)")
            #endif
        }

        // Never push Binding state back into PKCanvasView while the user is drawing.
        // The delegate owns drawing changes during an active PencilKit session.
        if !isDrawingEnabled, view.drawing != drawing {
            var resolved = drawing
            if referenceSize.width > 0, referenceSize.height > 0, canvasSize != referenceSize { resolved = drawing.transformed(using: CGAffineTransform(scaleX: canvasSize.width / referenceSize.width, y: canvasSize.height / referenceSize.height)) }
            context.coordinator.isApplyingDrawing = true
            view.drawing = resolved
            context.coordinator.isApplyingDrawing = false
        }
    }
    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) { if let observer = coordinator.undoObserver { NotificationCenter.default.removeObserver(observer) }; coordinator.undoObserver = nil; coordinator.canvas = nil }
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing
        weak var canvas: PKCanvasView?
        var undoObserver: NSObjectProtocol?
        var isApplyingDrawing = false
        var lastLoggedSize: CGSize = .zero
        var lastLoggedStrokeCount = -1
        var lastInteractionEnabled: Bool?

        init(drawing: Binding<PKDrawing>) { _drawing = drawing }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingDrawing else { return }
            drawing = canvasView.drawing
            let strokeCount = canvasView.drawing.strokes.count
            if strokeCount != lastLoggedStrokeCount {
                lastLoggedStrokeCount = strokeCount
                #if DEBUG
                print("[LockerPencil][DRAWING_CHANGED] strokes=\(strokeCount)")
                #endif
            }
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            #if DEBUG
            print("[LockerPencil][TOOL_BEGIN]")
            #endif
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            #if DEBUG
            print("[LockerPencil][TOOL_END]")
            #endif
        }
    }
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
