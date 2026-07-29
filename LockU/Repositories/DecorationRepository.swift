import Combine
import Foundation
import UIKit

@MainActor
final class DecorationRepository: ObservableObject {
    @Published private(set) var decorations: [LockerDecoration] = []

    private let paths: LockUPaths
    private let store: SafeJSONStore<LockerDecoration>
    private let imageCache = NSCache<NSString, UIImage>()

    init(paths: LockUPaths) {
        self.paths = paths
        store = SafeJSONStore(directory: paths.root, fileName: "decorations.json")
        imageCache.totalCostLimit = 64 * 1_024 * 1_024
    }

    func reload() throws {
        decorations = try store.load { [paths] record in
            FileManager.default.fileExists(
                atPath: paths.decorations.appendingPathComponent(record.imageFileName).path
            )
        }
        .sorted { $0.zIndex < $1.zIndex }
    }

    @discardableResult
    func add(
        image: UIImage,
        createdAt: Date = .now,
        initialPosition: CodablePoint = CodablePoint(x: 0.5, y: 0.52),
        initialScale: Double = 1
    ) throws -> LockerDecoration {
        guard let data = image.pngData() else { throw LockUStorageError.invalidImage }
        let id = UUID()
        let fileName = "decoration-\(id.uuidString).png"
        let imageURL = paths.decorations.appendingPathComponent(fileName)
        try data.write(to: imageURL, options: [.atomic])

        let record = LockerDecoration(
            id: id,
            createdAt: createdAt,
            imageFileName: fileName,
            position: initialPosition,
            scale: initialScale,
            rotationDegrees: 0,
            isFlipped: false,
            zIndex: (decorations.map(\.zIndex).max() ?? -1) + 1
        )
        do {
            decorations.append(record)
            try store.save(decorations)
            imageCache.setObject(
                image,
                forKey: fileName as NSString,
                cost: image.lockUDecorationByteCost
            )
            return record
        } catch {
            decorations.removeAll { $0.id == id }
            try? FileManager.default.removeItem(at: imageURL)
            throw error
        }
    }

    func image(for decoration: LockerDecoration) -> UIImage? {
        let key = decoration.imageFileName as NSString
        if let cached = imageCache.object(forKey: key) { return cached }
        guard let image = UIImage(
            contentsOfFile: paths.decorations.appendingPathComponent(decoration.imageFileName).path
        ) else { return nil }
        imageCache.setObject(image, forKey: key, cost: image.lockUDecorationByteCost)
        return image
    }

    func decoration(id: UUID) -> LockerDecoration? {
        decorations.first { $0.id == id }
    }

    func update(_ decoration: LockerDecoration) throws {
        guard let index = decorations.firstIndex(where: { $0.id == decoration.id }) else {
            throw LockUStorageError.recordNotFound
        }
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

        let imageURL = paths.decorations.appendingPathComponent(decoration.imageFileName)
        if FileManager.default.fileExists(atPath: imageURL.path) {
            try FileManager.default.removeItem(at: imageURL)
        }
        imageCache.removeObject(forKey: decoration.imageFileName as NSString)
    }

    func bringToFront(_ decoration: LockerDecoration) throws {
        guard var current = self.decoration(id: decoration.id) else {
            throw LockUStorageError.recordNotFound
        }
        current.zIndex = (decorations.map(\.zIndex).max() ?? 0) + 1
        try update(current)
    }
}

private extension UIImage {
    var lockUDecorationByteCost: Int {
        guard let cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
