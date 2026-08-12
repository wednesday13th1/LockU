import Combine
import Foundation
import UIKit

@MainActor
final class MemoryRepository: ObservableObject {
    @Published private(set) var memories: [MemoryRecord] = []

    private let store: MemoryMetadataStoring
    private let imageStorage: MemoryImageStoring
    private let imageCache: LockUImageCache
    private let dailyPolicy: DailyMemoryPolicy
    private lazy var captureWorkflow = CaptureMemoryWorkflow(repository: self, policy: dailyPolicy)

    init(
        paths: LockUPaths,
        calendar: Calendar = .current,
        imageStorage: MemoryImageStoring? = nil,
        imageCache: LockUImageCache? = nil,
        metadataStore: MemoryMetadataStoring? = nil
    ) {
        self.imageStorage = imageStorage ?? MemoryImageStorage(directory: paths.memories)
        self.imageCache = imageCache ?? LockUImageCache(costLimit: 96 * 1_024 * 1_024)
        dailyPolicy = DailyMemoryPolicy(calendar: calendar)
        store = metadataStore ?? MemoryMetadataStore(directory: paths.root)
    }

    func reload() throws {
        memories = try store.load().sorted { $0.createdAt > $1.createdAt }
    }

    func hasMemory(on date: Date) -> Bool {
        !dailyPolicy.canCreateMemory(on: date, existing: memories)
    }

    @discardableResult
    func saveImage(
        _ image: UIImage,
        createdAt: Date = .now,
        filterID: String? = nil,
        weather: WeatherSnapshot? = nil,
        captureMode: CaptureMode = .photoLibrary,
        imageStyle: MemoryImageStyle = .original,
        dailyFilm: DailyFilm? = nil,
        memoryNote: String? = nil
    ) throws -> MemoryRecord {
        try captureWorkflow.execute(CaptureMemoryRequest(image: image, createdAt: createdAt, filterID: filterID, weather: weather, captureMode: captureMode, imageStyle: imageStyle, dailyFilm: dailyFilm, memoryNote: memoryNote, origin: .dailyCapture, importedAt: nil)).memory
    }

    @discardableResult
    func importLegacyImage(_ image: UIImage, createdAt: Date) throws -> MemoryRecord {
        try createImageRecord(CaptureMemoryRequest(image: image, createdAt: createdAt, filterID: nil, weather: nil, captureMode: .legacy, imageStyle: .original, dailyFilm: nil, memoryNote: nil, origin: .legacy, importedAt: nil), enforceDailyLimit: false)
    }

    func createImageRecord(
        _ request: CaptureMemoryRequest,
        enforceDailyLimit: Bool
    ) throws -> MemoryRecord {
        LockULog.debug(.memory, "capture transaction started")
        if enforceDailyLimit { try dailyPolicy.validateCreation(on: request.createdAt, existing: memories) }
        let result = try CreateMemoryTransaction(imageStorage: imageStorage, metadataStore: store, cache: imageCache).execute(request, existing: memories)
        memories = result.records
        return result.record
    }

    func image(for memory: MemoryRecord) -> UIImage? {
        let key = memory.imageFileName
        if let cached = imageCache.image(forKey: key) { return cached }
        guard let image = imageStorage.load(fileName: key) else { return nil }
        imageCache.insert(image, forKey: key, cost: image.lockUApproximateStorageCost)
        return image
    }

    func markMemoryAsRevisited(id: UUID, at date: Date = .now) throws {
        guard let index = memories.firstIndex(where: { $0.id == id }) else { throw LockUStorageError.recordNotFound }
        var updated = memories
        updated[index].lastRevisitedAt = date
        updated[index].revisitCount += 1
        try store.save(updated)
        memories = updated
    }

    @discardableResult
    func importSeedMemories(_ items: [SeedMemoryImportItem], importedAt: Date = .now) async throws -> [MemoryRecord] {
        guard (5...7).contains(items.count) else { throw SeedMemoryImportError.invalidSelectionCount }
        let transaction = CreateSeedMemoriesTransaction(imageStorage: imageStorage, metadataStore: store, cache: imageCache)
        let existing = memories
        let result = try await Task.detached(priority: .userInitiated) {
            try transaction.execute(items: items, importedAt: importedAt, existing: existing)
        }.value
        memories = result.records
        return result.created
    }

    func rollbackSeedImport(ids: Set<UUID>) throws {
        let targets = memories.filter { ids.contains($0.id) && $0.origin == .seedImport }
        guard targets.count == ids.count else { return }
        let remaining = memories.filter { !ids.contains($0.id) }
        try store.save(remaining)
        for target in targets { try? imageStorage.delete(fileName: target.imageFileName) }
        memories = remaining
    }
}

enum SeedMemoryImportError: LocalizedError {
    case invalidSelectionCount
    var errorDescription: String? { "写真を5〜7枚選んでください。" }
}
