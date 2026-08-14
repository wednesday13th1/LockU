import Foundation
import AVFoundation
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
        let record = MemoryRecord(id: id, createdAt: request.createdAt, imageFileName: fileName, filterID: request.filterID, weather: request.weather, captureMode: request.captureMode, imageFormat: format, isSubjectCutout: request.imageStyle == .cutout, presentationStyle: DefaultMemoryPresentationPolicy().presentation(for: request.imageStyle, captureMode: request.captureMode), dailyFilmID: request.dailyFilm?.id, dailyFilmName: request.dailyFilm?.name, dailyFilmVersion: request.dailyFilm?.version, backImageFileName: fileName, memoryNote: request.memoryNote, moodEmoji: request.moodEmoji, dailyFilmIdentifier: request.dailyFilm?.id, origin: request.origin, importedAt: request.importedAt)
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

struct CreateVideoMemoryTransaction {
    let videoStorage: MemoryVideoStoring
    let imageStorage: MemoryImageStoring
    let metadataStore: MemoryMetadataStoring
    let cache: LockUImageCache

    func execute(
        temporaryVideoURL: URL,
        createdAt: Date,
        captureMode: CaptureMode,
        memoryNote: String?,
        existing: [MemoryRecord]
    ) async throws -> (record: MemoryRecord, records: [MemoryRecord]) {
        let id = UUID()
        try Task.checkCancellation()
        let sourceAsset = AVURLAsset(url: temporaryVideoURL)
        let duration = try await sourceAsset.load(.duration)
        guard duration.isNumeric, duration.seconds.isFinite, duration.seconds > 0 else {
            throw MemoryVideoError.invalidDuration
        }

        var videoFileName: String?
        var posterFileName: String?
        do {
            let savedVideoName = try videoStorage.saveVideo(from: temporaryVideoURL, id: id)
            videoFileName = savedVideoName
            try Task.checkCancellation()
            guard let savedURL = videoStorage.url(fileName: savedVideoName) else {
                throw MemoryVideoError.unsupportedOrMissingFile
            }
            let poster = try await makePoster(from: savedURL, duration: duration)
            try Task.checkCancellation()
            let savedPosterName = try imageStorage.saveJPEG(poster, id: id)
            posterFileName = savedPosterName

            let record = MemoryRecord(
                id: id,
                createdAt: createdAt,
                imageFileName: savedPosterName,
                captureMode: captureMode,
                imageFormat: .jpeg,
                isSubjectCutout: false,
                presentationStyle: .digicam,
                backImageFileName: savedPosterName,
                videoFileName: savedVideoName,
                videoThumbnailFileName: savedPosterName,
                memoryNote: memoryNote,
                origin: .dailyCapture
            )
            var records = existing + [record]
            records.sort { $0.createdAt > $1.createdAt }
            try metadataStore.save(records)
            cache.insert(poster, forKey: savedPosterName, cost: poster.lockUApproximateStorageCost)
            return (record, records)
        } catch {
            if let posterFileName { try? imageStorage.delete(fileName: posterFileName) }
            if let videoFileName { try? videoStorage.delete(fileName: videoFileName) }
            throw error
        }
    }

    private func makePoster(from url: URL, duration: CMTime) async throws -> UIImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 2_400, height: 2_400)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
        let seconds = min(0.2, max(0, duration.seconds * 0.5))
        do {
            let result = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
            return UIImage(cgImage: result.image).lockUDownsampled(maxDimension: 2_400)
        } catch {
            throw MemoryVideoError.thumbnailGenerationFailed
        }
    }
}

struct CreateDualCameraMemoryTransaction {
    let imageStorage: MemoryImageStoring
    let metadataStore: MemoryMetadataStoring
    let cache: LockUImageCache

    func execute(
        frontImage: UIImage,
        backImage: UIImage,
        createdAt: Date,
        memoryNote: String?,
        moodEmoji: String?,
        existing: [MemoryRecord]
    ) throws -> (record: MemoryRecord, records: [MemoryRecord]) {
        let id = UUID()
        var backFileName: String?
        var frontFileName: String?
        do {
            let savedBack = try imageStorage.saveDualBackJPEG(backImage, id: id)
            backFileName = savedBack
            let savedFront = try imageStorage.saveDualFrontJPEG(frontImage, id: id)
            frontFileName = savedFront

            let record = MemoryRecord(
                id: id,
                createdAt: createdAt,
                imageFileName: savedBack,
                captureMode: .camera,
                imageFormat: .jpeg,
                isSubjectCutout: false,
                presentationStyle: .digicam,
                frontImageFileName: savedFront,
                backImageFileName: savedBack,
                memoryNote: memoryNote,
                moodEmoji: moodEmoji,
                origin: .dailyCapture
            )
            var records = existing + [record]
            records.sort { $0.createdAt > $1.createdAt }
            try metadataStore.save(records)
            cache.insert(backImage, forKey: savedBack, cost: backImage.lockUApproximateStorageCost)
            cache.insert(frontImage, forKey: savedFront, cost: frontImage.lockUApproximateStorageCost)
            return (record, records)
        } catch {
            if let frontFileName { try? imageStorage.delete(fileName: frontFileName) }
            if let backFileName { try? imageStorage.delete(fileName: backFileName) }
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
