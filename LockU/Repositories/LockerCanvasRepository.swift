import Combine
import CoreGraphics
import Foundation

enum LockerCanvasError: LocalizedError {
    case textTooLong, userMemoryLimitReached, memoryAlreadyPlaced
    var errorDescription: String? {
        switch self {
        case .textTooLong: "文字は30文字以内で入力してください。"
        case .userMemoryLimitReached: "少し整理すると、別のMemoryを貼れます。"
        case .memoryAlreadyPlaced: "このMemoryはすでにロッカーにあります。"
        }
    }
}

@MainActor final class LockerCanvasRepository: ObservableObject {
    static let maximumUserMemories = 10
    @Published private(set) var metadata: LockerCanvasMetadata = .empty
    private let store: SafeJSONStore<LockerCanvasMetadata>
    private let drawingDirectory: URL
    private var cachedDrawingData: Data?

    init(paths: LockUPaths) {
        store = SafeJSONStore(directory: paths.root, fileName: "locker-canvas.json")
        drawingDirectory = paths.root.appendingPathComponent("LockerCanvas", isDirectory: true)
        try? FileManager.default.createDirectory(at: drawingDirectory, withIntermediateDirectories: true)
    }

    func reloadMetadata() throws { metadata = try store.load().first ?? .empty; cachedDrawingData = nil }

    func drawingData() -> Data? {
        if let cachedDrawingData { return cachedDrawingData }
        guard let name = metadata.drawingFileName else { return nil }
        let data = try? Data(contentsOf: drawingDirectory.appendingPathComponent(name), options: .mappedIfSafe)
        cachedDrawingData = data
        return data
    }

    func commit(texts: [LockerTextDecoration], placements: [LockerMemoryPlacement], drawingDecorations: [LockerDrawingDecoration], drawingData: Data?, drawingSize: CGSize?) throws {
        var next = metadata
        next.texts = texts; next.memoryPlacements = placements; next.drawingDecorations = drawingDecorations
        if let drawingData, !drawingData.isEmpty {
            let name = next.drawingFileName ?? "locker-drawing.pkdrawing"
            try drawingData.write(to: drawingDirectory.appendingPathComponent(name), options: .atomic)
            next.drawingFileName = name
            next.drawingReferenceWidth = drawingSize.map { Double($0.width) }
            next.drawingReferenceHeight = drawingSize.map { Double($0.height) }
            cachedDrawingData = drawingData
        }
        try store.save([next]); metadata = next
    }

    func addMemory(_ memoryID: UUID) throws {
        guard !metadata.memoryPlacements.contains(where: { $0.memoryID == memoryID }) else { throw LockerCanvasError.memoryAlreadyPlaced }
        guard metadata.memoryPlacements.filter({ $0.kind == .userAdded }).count < Self.maximumUserMemories else { throw LockerCanvasError.userMemoryLimitReached }
        var next = metadata
        next.memoryPlacements.append(LockerMemoryPlacement(id: UUID(), memoryID: memoryID, normalizedX: 0.5, normalizedY: 0.52, scale: 1, rotationDegrees: 0, zIndex: (next.memoryPlacements.map(\.zIndex).max() ?? 40) + 1, kind: .userAdded, createdAt: .now))
        try store.save([next]); metadata = next
    }

    func releaseRebuildableDisplayResources() { cachedDrawingData = nil }
}
