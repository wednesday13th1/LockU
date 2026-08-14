import PencilKit
import SwiftUI

struct LockerCanvasLayer: View {
    @EnvironmentObject private var canvasRepository: LockerCanvasRepository
    @EnvironmentObject private var memoryRepository: MemoryRepository
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isEditing = false
    @State private var isDrawing = false
    @State private var texts: [LockerTextDecoration] = []
    @State private var placements: [LockerMemoryPlacement] = []
    @State private var selectedTextID: UUID?
    @State private var selectedPlacementID: UUID?
    @State private var drawing = PKDrawing()
    @State private var drawingSize: CGSize = .zero
    @State private var currentCanvasSize: CGSize = .zero
    @State private var penColor = UIColor.white
    @State private var penWidth: CGFloat = 3
    @State private var erasing = false
    @State private var showTextEntry = false
    @State private var textEntry = ""
    @State private var showMemoryPicker = false
    @State private var errorMessage: String?
    @State private var snapshot: Snapshot?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LockerPencilCanvas(
                    drawing: $drawing, canvasSize: proxy.size, referenceSize: drawingSize,
                    isDrawingEnabled: isEditing && isDrawing, color: penColor,
                    width: penWidth, isEraser: erasing
                )
                .opacity(isEditing && isDrawing ? 0.68 : 0.46)
                .allowsHitTesting(isEditing && isDrawing)

                ForEach(texts) { decoration in
                    lockerText(decoration, size: proxy.size)
                }

                ForEach(placements.sorted { $0.zIndex < $1.zIndex }) { placement in
                    if let memory = memoryRepository.memories.first(where: { $0.id == placement.memoryID }) {
                        lockerMemory(memory, placement: placement, size: proxy.size)
                    }
                }

                if isEditing { editorChrome }
                else { editButton }
            }
            .onAppear { currentCanvasSize = proxy.size; load(size: proxy.size) }
            .onChange(of: proxy.size) { _, size in currentCanvasSize = size }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active, isEditing { save(size: proxy.size) }
            }
        }
        .sheet(isPresented: $showMemoryPicker) { LockerMemoryPicker(onSelect: addMemory) }
        .alert("文字を追加", isPresented: $showTextEntry) {
            TextField("summer!!", text: $textEntry)
            Button("Cancel", role: .cancel) { textEntry = "" }
            Button("Add") { addText() }
        } message: { Text("30文字までの短い言葉") }
        .alert("LockU", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var editButton: some View {
        VStack { HStack { Spacer(); Button("Edit") { beginEditing() }
            .font(.system(size: 11, weight: .semibold)).padding(.horizontal, 12).frame(height: 32)
            .background(.ultraThinMaterial, in: Capsule()).accessibilityLabel("Edit Locker") }; Spacer() }
        .padding(8)
    }

    private var editorChrome: some View {
        VStack {
            HStack {
                Button("Cancel", action: cancel).accessibilityLabel("Cancel Editing")
                Spacer()
                if let selectedTextID { Button("Remove") { texts.removeAll { $0.id == selectedTextID }; self.selectedTextID = nil } }
                if let selectedPlacementID { Button("Remove from Locker") { placements.removeAll { $0.id == selectedPlacementID }; self.selectedPlacementID = nil }.accessibilityLabel("Remove from Locker") }
                Button("Done") { saveAndFinish() }.accessibilityLabel("Finish Editing")
            }
            .font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).frame(height: 36)
            Spacer()
            if isDrawing { drawingTools }
            HStack(spacing: 24) {
                toolButton("pencil.tip", "DRAW") { isDrawing.toggle(); selectedTextID = nil; selectedPlacementID = nil }
                    .accessibilityLabel("Draw on Locker")
                toolButton("textformat", "WRITE") { isDrawing = false; showTextEntry = true }.accessibilityLabel("Add Text")
                toolButton("photo.on.rectangle", "+ MEMORY") { isDrawing = false; showMemoryPicker = true }.accessibilityLabel("Add Memory")
            }
            .padding(.horizontal, 18).frame(height: 48).background(.ultraThinMaterial, in: Capsule()).padding(.bottom, 6)
        }
        .foregroundStyle(LockUDesign.Color.schoolNavy)
    }

    private var drawingTools: some View {
        HStack(spacing: 10) {
            Button { erasing = false } label: { Image(systemName: "pencil.tip") }
            Button { erasing = true } label: { Image(systemName: "eraser") }
            Button { NotificationCenter.default.post(name: .lockerCanvasUndo, object: nil) } label: { Image(systemName: "arrow.uturn.backward") }
                .accessibilityLabel("Undo Drawing")
            ForEach([UIColor.white, UIColor(red: 0.06, green: 0.12, blue: 0.22, alpha: 1), UIColor.systemBlue, UIColor.systemPink, UIColor.black], id: \.self) { color in
                Button { penColor = color; erasing = false } label: { Circle().fill(Color(uiColor: color)).frame(width: 18, height: 18).overlay(Circle().stroke(.white.opacity(0.6))) }
            }
            ForEach([CGFloat(2), CGFloat(4), CGFloat(7)], id: \.self) { width in Button { penWidth = width } label: { Circle().fill(LockUDesign.Color.schoolNavy).frame(width: width + 4, height: width + 4) } }
        }
        .padding(.horizontal, 12).frame(height: 40).background(.thinMaterial, in: Capsule())
    }

    private func toolButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { VStack(spacing: 2) { Image(systemName: icon); Text(title).font(.system(size: 9, weight: .semibold)) } }
    }

    private func lockerText(_ item: LockerTextDecoration, size: CGSize) -> some View {
        Text(item.text).font(.system(size: 18, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.9))
            .shadow(color: .black.opacity(selectedTextID == item.id ? 0.12 : 0), radius: selectedTextID == item.id ? 2 : 0)
            .padding(6).overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(selectedTextID == item.id ? 0.55 : 0), lineWidth: 0.8))
            .scaleEffect(CGFloat(item.scale)).rotationEffect(.degrees(item.rotationDegrees))
            .position(x: CGFloat(item.normalizedX) * size.width, y: CGFloat(item.normalizedY) * size.height)
            .onTapGesture { guard isEditing, !isDrawing else { return }; selectedTextID = item.id; selectedPlacementID = nil }
            .gesture(isEditing && !isDrawing ? transformGesture(textID: item.id, size: size) : nil)
            .accessibilityLabel("Locker text, \(item.text)")
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
            .onTapGesture { guard isEditing, !isDrawing else { return }; selectedPlacementID = placement.id; selectedTextID = nil }
            .gesture(isEditing && !isDrawing ? transformGesture(placementID: placement.id, size: size) : nil)
    }

    private func transformGesture(textID: UUID? = nil, placementID: UUID? = nil, size: CGSize) -> some Gesture {
        let base = transformValues(textID, placementID)
        SimultaneousGesture(
            DragGesture().onChanged { value in mutate(textID, placementID) { x, y, _, _ in x = clamp(base.x + Double(value.translation.width / max(size.width, 1)), 0.08, 0.92); y = clamp(base.y + Double(value.translation.height / max(size.height, 1)), 0.08, 0.92) } },
            SimultaneousGesture(
                MagnificationGesture().onChanged { value in mutate(textID, placementID) { _, _, scale, _ in scale = clamp(base.scale * Double(value), 0.7, 1.5) } },
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
        if let textID, let i = texts.firstIndex(where: { $0.id == textID }) { change(&texts[i].normalizedX, &texts[i].normalizedY, &texts[i].scale, &texts[i].rotationDegrees) }
        if let placementID, let i = placements.firstIndex(where: { $0.id == placementID }) { change(&placements[i].normalizedX, &placements[i].normalizedY, &placements[i].scale, &placements[i].rotationDegrees) }
    }

    private func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double { min(max(value, low), high) }
    private func beginEditing() { snapshot = Snapshot(texts: texts, placements: placements, drawing: drawing); isEditing = true }
    private func cancel() { if let snapshot { texts = snapshot.texts; placements = snapshot.placements; drawing = snapshot.drawing }; isEditing = false; isDrawing = false }
    private func saveAndFinish() { save(size: currentCanvasSize); isEditing = false; isDrawing = false }
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
    private func addText() { let normalized = String(textEntry.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30)); guard !normalized.isEmpty else { return }; texts.append(LockerTextDecoration(id: UUID(), text: normalized, normalizedX: 0.5, normalizedY: 0.5, scale: 1, rotationDegrees: 0, createdAt: .now)); textEntry = "" }
    private func addMemory(_ memory: MemoryRecord) {
        guard !placements.contains(where: { $0.memoryID == memory.id }) else { errorMessage = LockerCanvasError.memoryAlreadyPlaced.localizedDescription; return }
        guard placements.filter({ $0.kind == .userAdded }).count < LockerCanvasRepository.maximumUserMemories else { errorMessage = LockerCanvasError.userMemoryLimitReached.localizedDescription; return }
        placements.append(LockerMemoryPlacement(id: UUID(), memoryID: memory.id, normalizedX: 0.5, normalizedY: 0.52, scale: 1, rotationDegrees: 0, zIndex: (placements.map(\.zIndex).max() ?? 40) + 1, kind: .userAdded, createdAt: .now))
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
            view.drawing = resolved
        }
    }
    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) { if let observer = coordinator.undoObserver { NotificationCenter.default.removeObserver(observer) }; coordinator.undoObserver = nil; coordinator.canvas = nil }
    final class Coordinator: NSObject, PKCanvasViewDelegate { @Binding var drawing: PKDrawing; weak var canvas: PKCanvasView?; var undoObserver: NSObjectProtocol?; init(drawing: Binding<PKDrawing>) { _drawing = drawing }; func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { drawing = canvasView.drawing } }
}

private extension Notification.Name { static let lockerCanvasUndo = Notification.Name("LockU.LockerCanvas.Undo") }

private struct LockerMemoryPicker: View {
    @EnvironmentObject private var repository: MemoryRepository
    @Environment(\.dismiss) private var dismiss
    let onSelect: (MemoryRecord) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    var body: some View { NavigationStack { ScrollView { LazyVGrid(columns: columns, spacing: 12) { ForEach(repository.memories.sorted { $0.memoryDate > $1.memoryDate }) { memory in Button { onSelect(memory) } label: { VStack(spacing: 4) { DownsampledLockerCanvasMemory(memory: memory).aspectRatio(1, contentMode: .fill).clipped(); Text(memory.memoryDate.formatted(.dateTime.month().day())).font(.caption2).foregroundStyle(.secondary) } }.buttonStyle(.plain) } }.padding() }.navigationTitle("Memoryを選ぶ").toolbar { Button("Close") { dismiss() } } } }
}

private struct DownsampledLockerCanvasMemory: View {
    @EnvironmentObject private var repository: MemoryRepository
    @State private var image: UIImage?
    let memory: MemoryRecord
    var body: some View { Group { if let image { Image(uiImage: image).resizable().scaledToFill() } else { Color.gray.opacity(0.35).overlay(ProgressView()) } }.task(id: memory.id) { image = await repository.imageAsync(for: memory, purpose: .locker, targetPointSize: CGSize(width: 150, height: 180)) }.onDisappear { image = nil } }
}
