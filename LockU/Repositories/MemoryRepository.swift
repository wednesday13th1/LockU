import Combine
import Foundation
import UIKit

@MainActor
final class MemoryRepository: ObservableObject {
    @Published private(set) var memories: [MemoryRecord] = []

    private let paths: LockUPaths
    private let store: SafeJSONStore<MemoryRecord>
    private let calendar: Calendar
    private let imageCache = NSCache<NSString, UIImage>()

    init(paths: LockUPaths, calendar: Calendar = .current) {
        self.paths = paths
        self.calendar = calendar
        store = SafeJSONStore(directory: paths.root, fileName: "memories.json")
        imageCache.totalCostLimit = 96 * 1_024 * 1_024
    }

    func reload() throws {
        memories = try store.load { [paths] record in
            FileManager.default.fileExists(
                atPath: paths.memories.appendingPathComponent(record.imageFileName).path
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    func hasMemory(on date: Date) -> Bool {
        memories.contains { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }

    @discardableResult
    func saveImage(
        _ image: UIImage,
        createdAt: Date = .now,
        filterID: String? = nil,
        weather: WeatherSnapshot? = nil,
        captureMode: CaptureMode = .photoLibrary,
        imageStyle: MemoryImageStyle = .original
    ) throws -> MemoryRecord {
        try persistImage(
            image,
            createdAt: createdAt,
            filterID: filterID,
            weather: weather,
            captureMode: captureMode,
            imageStyle: imageStyle,
            enforceDailyLimit: true
        )
    }

    @discardableResult
    func importLegacyImage(_ image: UIImage, createdAt: Date) throws -> MemoryRecord {
        try persistImage(
            image,
            createdAt: createdAt,
            filterID: nil,
            weather: nil,
            captureMode: .legacy,
            imageStyle: .original,
            enforceDailyLimit: false
        )
    }

    private func persistImage(
        _ image: UIImage,
        createdAt: Date,
        filterID: String?,
        weather: WeatherSnapshot?,
        captureMode: CaptureMode,
        imageStyle: MemoryImageStyle,
        enforceDailyLimit: Bool
    ) throws -> MemoryRecord {
        guard !enforceDailyLimit || !hasMemory(on: createdAt) else {
            throw MemoryRepositoryError.alreadyCapturedToday
        }
        let id = UUID()
        let data: Data
        let fileExtension: String
        let imageFormat: MemoryImageFormat
        switch imageStyle {
        case .original:
            guard let jpeg = image.jpegData(compressionQuality: 0.9) else {
                throw LockUStorageError.invalidImage
            }
            data = jpeg
            fileExtension = "jpg"
            imageFormat = .jpeg
        case .cutout:
            guard let png = image.pngData() else {
                throw LockUStorageError.invalidImage
            }
            data = png
            fileExtension = "png"
            imageFormat = .png
        }
        let fileName = "memory-\(id.uuidString).\(fileExtension)"
        let imageURL = paths.memories.appendingPathComponent(fileName)
        try data.write(to: imageURL, options: [.atomic])

        let record = MemoryRecord(
            id: id,
            createdAt: createdAt,
            imageFileName: fileName,
            filterID: filterID,
            weather: weather,
            captureMode: captureMode,
            imageFormat: imageFormat,
            isSubjectCutout: imageStyle == .cutout
        )
        do {
            memories.append(record)
            memories.sort { $0.createdAt > $1.createdAt }
            try store.save(memories)
            imageCache.setObject(
                image,
                forKey: fileName as NSString,
                cost: image.lockUApproximateByteCost
            )
            return record
        } catch {
            memories.removeAll { $0.id == id }
            try? FileManager.default.removeItem(at: imageURL)
            throw error
        }
    }

    func image(for memory: MemoryRecord) -> UIImage? {
        let key = memory.imageFileName as NSString
        if let cached = imageCache.object(forKey: key) { return cached }
        guard let image = UIImage(
            contentsOfFile: paths.memories.appendingPathComponent(memory.imageFileName).path
        ) else { return nil }
        imageCache.setObject(image, forKey: key, cost: image.lockUApproximateByteCost)
        return image
    }
}

private extension UIImage {
    var lockUApproximateByteCost: Int {
        guard let cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

enum MemoryRepositoryError: LocalizedError {
    case alreadyCapturedToday

    var errorDescription: String? {
        "今日の思い出はすでに保存されています。明日また撮影できます。"
    }
}
