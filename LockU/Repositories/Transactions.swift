import Foundation
import UIKit

struct CreateMemoryTransaction {
    let imageStorage: MemoryImageStoring
    let metadataStore: MemoryMetadataStoring
    let cache: LockUImageCache
    func execute(_ request: CaptureMemoryRequest, existing: [MemoryRecord]) throws -> (record: MemoryRecord, records: [MemoryRecord]) {
        let transactionID = String(UUID().uuidString.prefix(4)); let id = UUID(); let fileName: String; let format: MemoryImageFormat
        LockULog.debug(.transaction, "[TX:\(transactionID)] memory create started")
        switch ImageFormatPolicy().format(for: request.imageStyle) {
        case .jpeg: fileName = try imageStorage.saveJPEG(request.image, id: id); format = .jpeg
        case .png: fileName = try imageStorage.savePNG(request.image, id: id); format = .png
        }
        let record = MemoryRecord(id: id, createdAt: request.createdAt, imageFileName: fileName, filterID: request.filterID, weather: request.weather, captureMode: request.captureMode, imageFormat: format, isSubjectCutout: request.imageStyle == .cutout, presentationStyle: DefaultMemoryPresentationPolicy().presentation(for: request.imageStyle, captureMode: request.captureMode), dailyFilmID: request.dailyFilm?.id, dailyFilmName: request.dailyFilm?.name, dailyFilmVersion: request.dailyFilm?.version, backImageFileName: fileName, memoryNote: request.memoryNote, dailyFilmIdentifier: request.dailyFilm?.id, origin: request.origin, importedAt: request.importedAt)
        var updated = existing; updated.append(record); updated.sort { $0.createdAt > $1.createdAt }
        do {
            try metadataStore.save(updated)
            cache.insert(request.image, forKey: fileName, cost: request.image.lockUApproximateStorageCost)
            LockULog.debug(.transaction, "[TX:\(transactionID)] committed")
            return (record, updated)
        } catch {
            LockULog.error(.transaction, "[TX:\(transactionID)] metadata failed; rollback")
            try? imageStorage.delete(fileName: fileName); throw error
        }
    }
}

struct SeedMemoryImportItem {
    let image: UIImage
    let capturedAt: Date
}

struct CreateSeedMemoriesTransaction {
    let imageStorage: MemoryImageStoring
    let metadataStore: MemoryMetadataStoring
    let cache: LockUImageCache

    func execute(items: [SeedMemoryImportItem], importedAt: Date, existing: [MemoryRecord]) throws -> (records: [MemoryRecord], created: [MemoryRecord]) {
        var created: [MemoryRecord] = []
        do {
            for item in items {
                let id = UUID()
                let fileName = try imageStorage.saveJPEG(item.image, id: id)
                created.append(MemoryRecord(
                    id: id,
                    createdAt: item.capturedAt,
                    imageFileName: fileName,
                    captureMode: .photoLibrary,
                    imageFormat: .jpeg,
                    isSubjectCutout: false,
                    presentationStyle: .digicam,
                    backImageFileName: fileName,
                    origin: .seedImport,
                    importedAt: importedAt
                ))
            }
            var records = existing + created
            records.sort { $0.createdAt > $1.createdAt }
            try metadataStore.save(records)
            for (item, record) in zip(items, created) {
                cache.insert(item.image, forKey: record.imageFileName, cost: item.image.lockUApproximateStorageCost)
            }
            return (records, created)
        } catch {
            for record in created { try? imageStorage.delete(fileName: record.imageFileName) }
            throw error
        }
    }
}

struct CreateDecorationTransaction {
    let imageStorage: DecorationImageStoring
    let metadataStore: DecorationMetadataStoring
    let cache: LockUImageCache
    func execute(image: UIImage, record: LockerDecoration, existing: [LockerDecoration]) throws -> (record: LockerDecoration, records: [LockerDecoration]) {
        let fileName = try imageStorage.savePNG(image, id: record.id)
        var saved = record; saved = LockerDecoration(id: saved.id, createdAt: saved.createdAt, imageFileName: fileName, position: saved.position, scale: saved.scale, rotationDegrees: saved.rotationDegrees, isFlipped: saved.isFlipped, zIndex: saved.zIndex)
        var updated = existing; updated.append(saved)
        do { try metadataStore.save(updated); cache.insert(image, forKey: fileName, cost: image.lockUApproximateStorageCost); return (saved, updated) }
        catch { try? imageStorage.delete(fileName: fileName); throw error }
    }
}
