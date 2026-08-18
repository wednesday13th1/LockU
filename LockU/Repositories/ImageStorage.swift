import Foundation
import ImageIO
import UIKit

protocol MemoryImageStoring {
    func saveJPEG(_ image: UIImage, id: UUID) throws -> String
    func savePNG(_ image: UIImage, id: UUID) throws -> String
    func saveDualBackJPEG(_ image: UIImage, id: UUID) throws -> String
    func saveDualFrontJPEG(_ image: UIImage, id: UUID) throws -> String
    func load(fileName: String) -> UIImage?
    func load(fileName: String, targetPixelSize: CGFloat) -> UIImage?
    func url(fileName: String) -> URL?
    func delete(fileName: String) throws
    func exists(fileName: String) -> Bool
}

protocol MemoryVideoStoring {
    func saveVideo(from temporaryURL: URL, id: UUID) throws -> String
    func url(fileName: String) -> URL?
    func delete(fileName: String) throws
    func exists(fileName: String) -> Bool
}

final class MemoryVideoStorage: MemoryVideoStoring {
    private let directory: URL
    private let fileManager: FileManager
    private let supportedExtensions = Set(["mov", "mp4"])

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    func saveVideo(from temporaryURL: URL, id: UUID) throws -> String {
        let fileExtension = temporaryURL.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension),
              fileManager.fileExists(atPath: temporaryURL.path) else {
            throw MemoryVideoError.unsupportedOrMissingFile
        }
        let fileName = LockUFileNaming.video(id: id, extension: fileExtension)
        let destination = directory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: temporaryURL, to: destination)
        return fileName
    }

    func url(fileName: String) -> URL? {
        let candidate = directory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: candidate.path) ? candidate : nil
    }

    func delete(fileName: String) throws {
        let target = directory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: target.path) { try fileManager.removeItem(at: target) }
    }

    func exists(fileName: String) -> Bool {
        fileManager.fileExists(atPath: directory.appendingPathComponent(fileName).path)
    }
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
    func saveDualBackJPEG(_ image: UIImage, id: UUID) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.9) else { throw LockUStorageError.invalidImage }
        return try save(data, fileName: LockUFileNaming.memoryBack(id: id))
    }
    func saveDualFrontJPEG(_ image: UIImage, id: UUID) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.9) else { throw LockUStorageError.invalidImage }
        return try save(data, fileName: LockUFileNaming.memoryFront(id: id))
    }
    func load(fileName: String) -> UIImage? {
        let url = directory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    func load(fileName: String, targetPixelSize: CGFloat) -> UIImage? {
        let url = directory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: url.path), targetPixelSize > 0 else { return nil }
        return Self.downsampledImage(at: url, targetPixelSize: targetPixelSize)
    }
    nonisolated static func downsampledImage(at url: URL, targetPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(ceil(targetPixelSize))
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
    func url(fileName: String) -> URL? {
        let url = directory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
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
        let name = LockUFileNaming.decoration(id: id)
        let url = directory.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic])
        guard UIImage(contentsOfFile: url.path) != nil else {
            try? fileManager.removeItem(at: url)
            throw LockUStorageError.invalidImage
        }
        return name
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
        return MemoryImageStorage.downsampledImage(at: currentURL, targetPixelSize: 2_048)
    }
    func exists() -> Bool { fileManager.fileExists(atPath: currentURL.path) }
    func delete() throws { if exists() { try fileManager.removeItem(at: currentURL) } }
}

enum ImageStorageFailure: Error { case encodingFailed, verificationFailed }

enum LockUFileNaming {
    static func memory(id: UUID, extension ext: String) -> String { "memory-\(id.uuidString).\(ext)" }
    static func video(id: UUID, extension ext: String) -> String { "memory-video-\(id.uuidString).\(ext)" }
    static func memoryBack(id: UUID) -> String { "memory-\(id.uuidString)-back.jpg" }
    static func memoryFront(id: UUID) -> String { "memory-\(id.uuidString)-front.jpg" }
    static func decoration(id: UUID) -> String { "decoration-\(id.uuidString).png" }
    static let background = "background-current.jpg"
}

enum MemoryVideoError: LocalizedError {
    case unsupportedOrMissingFile
    case invalidDuration
    case thumbnailGenerationFailed
    case saveAlreadyInProgress

    var errorDescription: String? {
        switch self {
        case .unsupportedOrMissingFile: "動画ファイルを読み込めませんでした。"
        case .invalidDuration: "有効な長さの動画を選んでください。"
        case .thumbnailGenerationFailed: "動画のプレビューを作成できませんでした。"
        case .saveAlreadyInProgress: "動画を保存しています。完了までお待ちください。"
        }
    }
}

private nonisolated final class LockUImageCacheBox: @unchecked Sendable {
    let cache = NSCache<NSString, UIImage>()
}

@MainActor
final class LockUImageCache {
    private let box = LockUImageCacheBox()
    private var memoryWarningObserver: NSObjectProtocol?

    init(costLimit: Int, countLimit: Int = 24) {
        box.cache.totalCostLimit = costLimit
        box.cache.countLimit = countLimit
        let box = box
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            box.cache.removeAllObjects()
        }
    }

    deinit {
        if let memoryWarningObserver { NotificationCenter.default.removeObserver(memoryWarningObserver) }
    }
    func image(forKey key: String) -> UIImage? { box.cache.object(forKey: key as NSString) }
    func insert(_ image: UIImage, forKey key: String, cost: Int) { box.cache.setObject(image, forKey: key as NSString, cost: cost) }
    func remove(forKey key: String) { box.cache.removeObject(forKey: key as NSString) }
    func clear() { box.cache.removeAllObjects() }
}

extension UIImage {
    var lockUApproximateStorageCost: Int { cgImage.map { $0.bytesPerRow * $0.height } ?? 0 }
}
