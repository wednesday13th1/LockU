import Combine
import Foundation
import UIKit

enum MemoryImagePurpose: String, Sendable {
    case locker
    case peek
    case detail
}

private nonisolated struct SendableImage: @unchecked Sendable {
    let image: UIImage?
}

@MainActor
final class MemoryRepository: ObservableObject {
    @Published private(set) var memories: [MemoryRecord] = []

    private let store: MemoryMetadataStoring
    private let imageStorage: MemoryImageStoring
    private let videoStorage: MemoryVideoStoring
    private let imageCache: LockUImageCache
    private let dailyPolicy: DailyMemoryPolicy
    private var isSavingVideoMemory = false
    private lazy var captureWorkflow = CaptureMemoryWorkflow(repository: self, policy: dailyPolicy)

    init(
        paths: LockUPaths,
        calendar: Calendar = .current,
        imageStorage: MemoryImageStoring? = nil,
        videoStorage: MemoryVideoStoring? = nil,
        imageCache: LockUImageCache? = nil,
        metadataStore: MemoryMetadataStoring? = nil
    ) {
        self.imageStorage = imageStorage ?? MemoryImageStorage(directory: paths.memories)
        self.videoStorage = videoStorage ?? MemoryVideoStorage(directory: paths.videos)
        self.imageCache = imageCache ?? LockUImageCache(costLimit: 80 * 1_024 * 1_024)
        dailyPolicy = DailyMemoryPolicy(calendar: calendar)
        store = metadataStore ?? MemoryMetadataStore(directory: paths.root)
    }

    func reload() throws {
        memories = try store.load().sorted { $0.createdAt > $1.createdAt }
    }

    /// Camera owns the foreground resource budget while it is visible. These images are
    /// rebuildable display derivatives; originals and metadata remain untouched.
    func releaseRebuildableDisplayResources() {
        imageCache.clear()
        LockULog.debug(.cache, "Released rebuildable memory images for Camera priority mode")
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
        if let image = loadImage(fileName: memory.imageFileName) { return image }
        guard let frontFileName = memory.frontImageFileName else { return nil }
        return loadImage(fileName: frontFileName)
    }

    func image(
        for memory: MemoryRecord,
        purpose: MemoryImagePurpose,
        targetPointSize: CGSize,
        displayScale: CGFloat? = nil
    ) -> UIImage? {
        let resolvedDisplayScale = displayScale ?? UIScreen.main.scale
        let fileName = memory.imageFileName
        if let image = loadImage(
            fileName: fileName,
            purpose: purpose,
            targetPointSize: targetPointSize,
            displayScale: resolvedDisplayScale
        ) { return image }
        guard let frontFileName = memory.frontImageFileName else { return nil }
        return loadImage(
            fileName: frontFileName,
            purpose: purpose,
            targetPointSize: targetPointSize,
            displayScale: resolvedDisplayScale
        )
    }

    func imageAsync(
        for memory: MemoryRecord,
        purpose: MemoryImagePurpose,
        targetPointSize: CGSize,
        displayScale: CGFloat? = nil
    ) async -> UIImage? {
        let resolvedDisplayScale = displayScale ?? UIScreen.main.scale
        let candidates = [memory.imageFileName, memory.frontImageFileName].compactMap { $0 }
        for fileName in candidates {
            let pixelWidth = max(1, Int(ceil(targetPointSize.width * resolvedDisplayScale)))
            let pixelHeight = max(1, Int(ceil(targetPointSize.height * resolvedDisplayScale)))
            let cacheKey = "\(fileName)-\(purpose.rawValue)-\(pixelWidth)x\(pixelHeight)"
            if let cached = imageCache.image(forKey: cacheKey) { return cached }
            guard let url = imageStorage.url(fileName: fileName) else { continue }
            let maximumPixelDimension = CGFloat(max(pixelWidth, pixelHeight))
            let loadTask = Task.detached(priority: .userInitiated) {
                SendableImage(image: MemoryImageStorage.downsampledImage(at: url, targetPixelSize: maximumPixelDimension))
            }
            let loaded = await withTaskCancellationHandler {
                await loadTask.value
            } onCancel: {
                loadTask.cancel()
            }
            guard !Task.isCancelled, let image = loaded.image else { continue }
            imageCache.insert(image, forKey: cacheKey, cost: image.lockUApproximateStorageCost)
            return image
        }
        return nil
    }


    func frontImage(for memory: MemoryRecord) -> UIImage? {
        guard let fileName = memory.frontImageFileName else { return nil }
        return loadImage(fileName: fileName)
    }

    func frontImage(for memory: MemoryRecord, purpose: MemoryImagePurpose, targetPointSize: CGSize) -> UIImage? {
        guard let fileName = memory.frontImageFileName else { return nil }
        return loadImage(fileName: fileName, purpose: purpose, targetPointSize: targetPointSize, displayScale: UIScreen.main.scale)
    }

    func backImage(for memory: MemoryRecord) -> UIImage? {
        let fileName = memory.backImageFileName ?? memory.imageFileName
        return loadImage(fileName: fileName)
    }

    func backImage(for memory: MemoryRecord, purpose: MemoryImagePurpose, targetPointSize: CGSize) -> UIImage? {
        let fileName = memory.backImageFileName ?? memory.imageFileName
        return loadImage(fileName: fileName, purpose: purpose, targetPointSize: targetPointSize, displayScale: UIScreen.main.scale)
    }

    func hasFrontImage(for memory: MemoryRecord) -> Bool {
        memory.frontImageFileName.map { imageStorage.exists(fileName: $0) } ?? false
    }

    func hasBackImage(for memory: MemoryRecord) -> Bool {
        let fileName = memory.backImageFileName ?? memory.imageFileName
        return imageStorage.exists(fileName: fileName)
    }

    @discardableResult
    func saveDualCameraMemory(
        frontImage: UIImage,
        backImage: UIImage,
        createdAt: Date = .now,
        memoryNote: String? = nil
    ) throws -> MemoryRecord {
        try dailyPolicy.validateCreation(on: createdAt, existing: memories)
        let normalizedNote = try MemoryNotePolicy().normalize(memoryNote)
        let normalizedFront = frontImage.lockUNormalized().lockUDownsampled(maxDimension: 2_400)
        let normalizedBack = backImage.lockUNormalized().lockUDownsampled(maxDimension: 2_400)
        let result = try CreateDualCameraMemoryTransaction(
            imageStorage: imageStorage,
            metadataStore: store,
            cache: imageCache
        ).execute(
            frontImage: normalizedFront,
            backImage: normalizedBack,
            createdAt: createdAt,
            memoryNote: normalizedNote,
            existing: memories
        )
        memories = result.records
        return result.record
    }

    private func loadImage(fileName: String) -> UIImage? {
        if let cached = imageCache.image(forKey: fileName) { return cached }
        guard let image = imageStorage.load(fileName: fileName) else { return nil }
        imageCache.insert(image, forKey: fileName, cost: image.lockUApproximateStorageCost)
        return image
    }

    private func loadImage(
        fileName: String,
        purpose: MemoryImagePurpose,
        targetPointSize: CGSize,
        displayScale: CGFloat
    ) -> UIImage? {
        let pixelWidth = max(1, Int(ceil(targetPointSize.width * displayScale)))
        let pixelHeight = max(1, Int(ceil(targetPointSize.height * displayScale)))
        let maximumPixelDimension = CGFloat(max(pixelWidth, pixelHeight))
        let cacheKey = "\(fileName)-\(purpose.rawValue)-\(pixelWidth)x\(pixelHeight)"
        if let cached = imageCache.image(forKey: cacheKey) { return cached }
        guard let image = imageStorage.load(fileName: fileName, targetPixelSize: maximumPixelDimension) else { return nil }
        imageCache.insert(image, forKey: cacheKey, cost: image.lockUApproximateStorageCost)
        return image
    }

    func videoURL(for memory: MemoryRecord) -> URL? {
        guard let fileName = memory.videoFileName else { return nil }
        return videoStorage.url(fileName: fileName)
    }

    @discardableResult
    func saveVideoMemory(
        temporaryVideoURL: URL,
        createdAt: Date = .now,
        captureMode: CaptureMode = .photoLibrary,
        memoryNote: String? = nil
    ) async throws -> MemoryRecord {
        guard !isSavingVideoMemory else { throw MemoryVideoError.saveAlreadyInProgress }
        isSavingVideoMemory = true
        defer { isSavingVideoMemory = false }
        try dailyPolicy.validateCreation(on: createdAt, existing: memories)
        let normalizedNote = try MemoryNotePolicy().normalize(memoryNote)
        let transaction = CreateVideoMemoryTransaction(
            videoStorage: videoStorage,
            imageStorage: imageStorage,
            metadataStore: store,
            cache: imageCache
        )
        let existing = memories
        let result = try await transaction.execute(
            temporaryVideoURL: temporaryVideoURL,
            createdAt: createdAt,
            captureMode: captureMode,
            memoryNote: normalizedNote,
            existing: existing
        )
        memories = result.records
        return result.record
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
        guard items.count == LockerMemoryLayout.photoSlotCount else {
            throw SeedMemoryImportError.invalidSelectionCount
        }
        let transaction = CreateSeedMemoriesTransaction(imageStorage: imageStorage, metadataStore: store, cache: imageCache)
        let existing = memories
        let result = try transaction.execute(items: items, importedAt: importedAt, existing: existing)
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
    var errorDescription: String? {
        "写真を\(LockerMemoryLayout.photoSlotCount)枚選んでください。"
    }
}

@MainActor
final class MemoryReflectionRepository: ObservableObject {
    @Published private(set) var reflections: [MemoryReflection] = []

    private let store: MemoryReflectionMetadataStoring

    init(paths: LockUPaths, metadataStore: MemoryReflectionMetadataStoring? = nil) {
        store = metadataStore ?? MemoryReflectionMetadataStore(directory: paths.root)
    }

    func reload() throws {
        reflections = try store.load().sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func add(memoryID: UUID, text: String, createdAt: Date) throws -> MemoryReflection? {
        guard let normalized = try MemoryReflectionPolicy.normalized(text) else { return nil }
        let reflection = MemoryReflection(id: UUID(), memoryID: memoryID, text: normalized, createdAt: createdAt)
        var updated = reflections
        updated.append(reflection)
        updated.sort { $0.createdAt > $1.createdAt }
        try store.save(updated)
        reflections = updated
        return reflection
    }

    func delete(id: UUID) throws {
        guard reflections.contains(where: { $0.id == id }) else { return }
        let updated = reflections.filter { $0.id != id }
        try store.save(updated)
        reflections = updated
    }

    func reflections(for memoryID: UUID) -> [MemoryReflection] {
        reflections.filter { $0.memoryID == memoryID }.sorted { $0.createdAt > $1.createdAt }
    }
}
