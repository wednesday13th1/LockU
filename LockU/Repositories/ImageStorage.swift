import Foundation
import UIKit

protocol MemoryImageStoring {
    func saveJPEG(_ image: UIImage, id: UUID) throws -> String
    func savePNG(_ image: UIImage, id: UUID) throws -> String
    func load(fileName: String) -> UIImage?
    func delete(fileName: String) throws
    func exists(fileName: String) -> Bool
}

final class MemoryImageStorage: MemoryImageStoring {
    private let directory: URL
    private let fileManager: FileManager
    init(directory: URL, fileManager: FileManager = .default) { self.directory = directory; self.fileManager = fileManager }
    func saveJPEG(_ image: UIImage, id: UUID) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.9) else { throw LockUStorageError.invalidImage }
        return try save(data, fileName: LockUFileNaming.memory(id: id, extension: "jpg"))
    }
    func savePNG(_ image: UIImage, id: UUID) throws -> String {
        guard let data = image.pngData() else { throw LockUStorageError.invalidImage }
        return try save(data, fileName: LockUFileNaming.memory(id: id, extension: "png"))
    }
    func load(fileName: String) -> UIImage? {
        let url = directory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    func delete(fileName: String) throws { let url = directory.appendingPathComponent(fileName); if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) } }
    func exists(fileName: String) -> Bool { fileManager.fileExists(atPath: directory.appendingPathComponent(fileName).path) }
    private func save(_ data: Data, fileName: String) throws -> String { try data.write(to: directory.appendingPathComponent(fileName), options: [.atomic]); return fileName }
}

protocol DecorationImageStoring {
    func savePNG(_ image: UIImage, id: UUID) throws -> String
    func load(fileName: String) -> UIImage?
    func delete(fileName: String) throws
    func exists(fileName: String) -> Bool
}

final class DecorationImageStorage: DecorationImageStoring {
    private let directory: URL
    private let fileManager: FileManager
    init(directory: URL, fileManager: FileManager = .default) { self.directory = directory; self.fileManager = fileManager }
    func savePNG(_ image: UIImage, id: UUID) throws -> String {
        guard let data = image.pngData() else { throw LockUStorageError.invalidImage }
        let name = LockUFileNaming.decoration(id: id); try data.write(to: directory.appendingPathComponent(name), options: [.atomic]); return name
    }
    func load(fileName: String) -> UIImage? {
        let url = directory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    func delete(fileName: String) throws { let url = directory.appendingPathComponent(fileName); if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) } }
    func exists(fileName: String) -> Bool { fileManager.fileExists(atPath: directory.appendingPathComponent(fileName).path) }
}

protocol BackgroundImageStoring {
    func save(_ image: UIImage) throws
    func load() -> UIImage?
    func exists() -> Bool
    func delete() throws
}

final class BackgroundImageStorage: BackgroundImageStoring {
    private let currentURL: URL
    private let temporaryURL: URL
    private let fileManager: FileManager
    private let quality: CGFloat
    init(directory: URL, fileManager: FileManager = .default, compressionQuality: CGFloat = 0.9) {
        currentURL = directory.appendingPathComponent(LockUFileNaming.background)
        temporaryURL = directory.appendingPathComponent("background-pending.tmp")
        self.fileManager = fileManager; quality = compressionQuality
    }
    func save(_ image: UIImage) throws {
        guard let data = image.jpegData(compressionQuality: quality) else { throw ImageStorageFailure.encodingFailed }
        try data.write(to: temporaryURL, options: [.atomic])
        guard UIImage(contentsOfFile: temporaryURL.path) != nil else { try? fileManager.removeItem(at: temporaryURL); throw ImageStorageFailure.verificationFailed }
        do {
            if fileManager.fileExists(atPath: currentURL.path) { _ = try fileManager.replaceItemAt(currentURL, withItemAt: temporaryURL) }
            else { try fileManager.moveItem(at: temporaryURL, to: currentURL) }
        } catch { try? fileManager.removeItem(at: temporaryURL); throw error }
    }
    func load() -> UIImage? {
        guard fileManager.fileExists(atPath: currentURL.path) else { return nil }
        return UIImage(contentsOfFile: currentURL.path)
    }
    func exists() -> Bool { fileManager.fileExists(atPath: currentURL.path) }
    func delete() throws { if exists() { try fileManager.removeItem(at: currentURL) } }
}

enum ImageStorageFailure: Error { case encodingFailed, verificationFailed }

enum LockUFileNaming {
    static func memory(id: UUID, extension ext: String) -> String { "memory-\(id.uuidString).\(ext)" }
    static func decoration(id: UUID) -> String { "decoration-\(id.uuidString).png" }
    static let background = "background-current.jpg"
}

final class LockUImageCache {
    private let cache = NSCache<NSString, UIImage>()
    init(costLimit: Int) { cache.totalCostLimit = costLimit }
    func image(forKey key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func insert(_ image: UIImage, forKey key: String, cost: Int) { cache.setObject(image, forKey: key as NSString, cost: cost) }
    func remove(forKey key: String) { cache.removeObject(forKey: key as NSString) }
    func clear() { cache.removeAllObjects() }
}

extension UIImage {
    var lockUApproximateStorageCost: Int { cgImage.map { $0.bytesPerRow * $0.height } ?? 0 }
}
