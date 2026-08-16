import Combine
import CoreGraphics
import Foundation
import UIKit

enum LockerCanvasError: LocalizedError {
    case textTooLong, userMemoryLimitReached, memoryAlreadyPlaced, topShelfDecorationLimitReached
    var errorDescription: String? {
        switch self {
        case .textTooLong: "文字は30文字以内で入力してください。"
        case .userMemoryLimitReached: "少し整理すると、別のMemoryを貼れます。"
        case .memoryAlreadyPlaced: "このMemoryはすでにロッカーにあります。"
        case .topShelfDecorationLimitReached: "上の棚には5個まで置けます。"
        }
    }
}

@MainActor final class LockerCanvasRepository: ObservableObject {
    static let maximumUserMemories = 10
    static let maximumTopShelfDecorations = 5
    @Published private(set) var metadata: LockerCanvasMetadata = .empty
    private let store: SafeJSONStore<LockerCanvasMetadata>
    private let drawingDirectory: URL
    private let decorationImageStorage: DecorationImageStoring
    private var cachedDrawingData: Data?

    init(paths: LockUPaths) {
        store = SafeJSONStore(directory: paths.root, fileName: "locker-canvas.json")
        drawingDirectory = paths.root.appendingPathComponent("LockerCanvas", isDirectory: true)
        decorationImageStorage = DecorationImageStorage(directory: paths.decorations)
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

    @discardableResult
    func addTopShelfDecoration(image: UIImage, createdAt: Date = .now) throws -> LockerTopShelfDecoration {
        guard metadata.topShelfDecorations.count < Self.maximumTopShelfDecorations else {
            throw LockerCanvasError.topShelfDecorationLimitReached
        }
        let index = metadata.topShelfDecorations.count
        let positions: [Double] = [0.5, 0.34, 0.66, 0.22, 0.78]
        let rotations: [Double] = [0, -4, 4, -2, 2]
        let id = UUID()
        let fileName = try decorationImageStorage.savePNG(image, id: id)
        let decoration = LockerTopShelfDecoration(
            id: id,
            imageFileName: fileName,
            normalizedX: positions[index],
            normalizedY: 0.48,
            scale: 0.72,
            rotationDegrees: rotations[index],
            zIndex: (metadata.topShelfDecorations.map(\.zIndex).max() ?? -1) + 1,
            createdAt: createdAt
        )
        var next = metadata
        next.topShelfDecorations.append(decoration)
        do {
            try store.save([next])
            metadata = next
            return decoration
        } catch {
            try? decorationImageStorage.delete(fileName: fileName)
            throw error
        }
    }

    func updateTopShelfDecoration(_ decoration: LockerTopShelfDecoration) throws {
        guard let index = metadata.topShelfDecorations.firstIndex(where: { $0.id == decoration.id }) else {
            throw LockUStorageError.recordNotFound
        }
        var next = metadata
        next.topShelfDecorations[index] = decoration
        try store.save([next])
        metadata = next
    }

    func deleteTopShelfDecoration(_ decoration: LockerTopShelfDecoration) throws {
        guard metadata.topShelfDecorations.contains(where: { $0.id == decoration.id }) else {
            throw LockUStorageError.recordNotFound
        }
        var next = metadata
        next.topShelfDecorations.removeAll { $0.id == decoration.id }
        try store.save([next])
        metadata = next
        try decorationImageStorage.delete(fileName: decoration.imageFileName)
    }

    func topShelfImage(for decoration: LockerTopShelfDecoration) -> UIImage? {
        decorationImageStorage.load(fileName: decoration.imageFileName)
    }

    func releaseRebuildableDisplayResources() { cachedDrawingData = nil }
}
