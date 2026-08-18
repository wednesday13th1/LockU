import Combine
import Foundation
import UIKit

@MainActor
final class DecorationRepository: ObservableObject {
    static let maximumDoorDecorations = 5
    @Published private(set) var decorations: [LockerDecoration] = []

    private let store: DecorationMetadataStoring
    private let imageStorage: DecorationImageStoring
    private let imageCache: LockUImageCache

    init(paths: LockUPaths, imageStorage: DecorationImageStoring? = nil, imageCache: LockUImageCache? = nil, metadataStore: DecorationMetadataStoring? = nil) {
        self.imageStorage = imageStorage ?? DecorationImageStorage(directory: paths.decorations)
        self.imageCache = imageCache ?? LockUImageCache(costLimit: 64 * 1_024 * 1_024)
        store = metadataStore ?? DecorationMetadataStore(directory: paths.root)
    }

    func reload() throws {
        let loaded = try store.load()
        var restored: [LockerDecoration] = []
        for var decoration in loaded where imageStorage.exists(fileName: decoration.imageFileName) {
            decoration.placement = LockerPlacementEngine().clampToBounds(decoration.placement)
            restored.append(decoration)
        }
        restored.sort { $0.zIndex < $1.zIndex }
        decorations = restored
        if restored != loaded { try store.save(restored) }
        #if DEBUG
        print("[LockerEdit][RESTORE_SUCCESS] decorations=\(restored.count)")
        #endif
    }

    @discardableResult
    func add(
        image: UIImage,
        createdAt: Date = .now,
        initialPosition: CodablePoint = CodablePoint(x: 0.5, y: 0.52),
        initialScale: Double = 1
    ) throws -> LockerDecoration {
        guard decorations.count < Self.maximumDoorDecorations else {
            throw DecorationRepositoryError.maximumReached
        }
        LockULog.debug(.decoration, "add transaction started")
        let id = UUID()
        let record = LockerDecoration(
            id: id,
            createdAt: createdAt,
            imageFileName: LockUFileNaming.decoration(id: id),
            position: initialPosition,
            scale: initialScale,
            rotationDegrees: 0,
            isFlipped: false,
            zIndex: (decorations.map(\.zIndex).max() ?? -1) + 1
        )
        let result = try CreateDecorationTransaction(imageStorage: imageStorage, metadataStore: store, cache: imageCache).execute(image: image, record: record, existing: decorations)
        decorations = result.records
        #if DEBUG
        print("[LockerDecor][SAVED] id=\(result.record.id)")
        #endif
        LockULog.debug(.decoration, "add transaction committed")
        return result.record
    }

    func image(for decoration: LockerDecoration) -> UIImage? {
        let key = decoration.imageFileName
        if let cached = imageCache.image(forKey: key) { return cached }
        guard let image = imageStorage.load(fileName: key) else { return nil }
        imageCache.insert(image, forKey: key, cost: image.lockUApproximateStorageCost)
        return image
    }

    func decoration(id: UUID) -> LockerDecoration? {
        decorations.first { $0.id == id }
    }

    func update(_ decoration: LockerDecoration) throws {
        guard let index = decorations.firstIndex(where: { $0.id == decoration.id }) else {
            throw LockUStorageError.recordNotFound
        }
        var decoration = decoration
        decoration.placement = LockerPlacementEngine().clampToBounds(decoration.placement)
        let previous = decorations
        decorations[index] = decoration
        decorations.sort { $0.zIndex < $1.zIndex }
        do {
            try store.save(decorations)
        } catch {
            decorations = previous
            throw error
        }
    }

    func delete(_ decoration: LockerDecoration) throws {
        guard decorations.contains(where: { $0.id == decoration.id }) else {
            throw LockUStorageError.recordNotFound
        }
        let previous = decorations
        decorations.removeAll { $0.id == decoration.id }
        do {
            try store.save(decorations)
        } catch {
            decorations = previous
            throw error
        }

        do {
            try imageStorage.delete(fileName: decoration.imageFileName)
        } catch {
            decorations = previous
            try? store.save(previous)
            throw error
        }
        imageCache.remove(forKey: decoration.imageFileName)
        #if DEBUG
        print("[LockerDecor][REMOVED] id=\(decoration.id)")
        #endif
    }

}

enum DecorationRepositoryError: LocalizedError {
    case maximumReached
    var errorDescription: String? { "ドアには5個まで貼れます" }
}
