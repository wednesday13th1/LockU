import Foundation

enum LockUError: Error {
    case storage(StorageFailure)
    case media(MediaFailure)
    case policy(PolicyFailure)
    case migration(MigrationFailure)
    case recovery(RecoveryFailure)
}

enum StorageFailure: Error { case metadataReadFailed, metadataWriteFailed, imageWriteFailed, imageDeleteFailed }
enum MediaFailure: Error { case encodingFailed, missingFile }
enum PolicyFailure: Error { case dailyLimitReached, invalidPlacement }
enum MigrationFailure: Error { case unsupportedSchema(Int), conversionFailed }
enum RecoveryFailure: Error { case inspectionFailed, unsafeRepairRequired }

enum LockUStorageError: LocalizedError {
    case applicationSupportUnavailable
    case invalidImage
    case recordNotFound
    case noRecoverableMetadata(String)

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return "Application Supportフォルダを利用できません。"
        case .invalidImage:
            return "選択した画像を保存可能な形式へ変換できませんでした。"
        case .recordNotFound:
            return "指定されたデータが見つかりません。"
        case .noRecoverableMetadata(let name):
            return "\(name)のメタデータを復元できませんでした。"
        }
    }
}

struct LockUPaths: Sendable {
    let root: URL
    let memories: URL
    let videos: URL
    let decorations: URL
    let backgrounds: URL

    init(fileManager: FileManager = .default) throws {
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw LockUStorageError.applicationSupportUnavailable
        }
        root = applicationSupport.appendingPathComponent("LockU", isDirectory: true)
        memories = root.appendingPathComponent("Memories", isDirectory: true)
        videos = root.appendingPathComponent("Videos", isDirectory: true)
        decorations = root.appendingPathComponent("Decorations", isDirectory: true)
        backgrounds = root.appendingPathComponent("Backgrounds", isDirectory: true)
        for directory in [root, memories, videos, decorations, backgrounds] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    init(recoveryRoot: URL, fileManager: FileManager = .default) {
        root = recoveryRoot
        memories = root.appendingPathComponent("Memories", isDirectory: true)
        videos = root.appendingPathComponent("Videos", isDirectory: true)
        decorations = root.appendingPathComponent("Decorations", isDirectory: true)
        backgrounds = root.appendingPathComponent("Backgrounds", isDirectory: true)
        for directory in [root, memories, videos, decorations, backgrounds] {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}

struct SafeJSONStore<Record: Codable & Identifiable> where Record.ID == UUID {
    let fileURL: URL
    let backupURL: URL

    init(directory: URL, fileName: String) {
        fileURL = directory.appendingPathComponent(fileName)
        backupURL = directory.appendingPathComponent(fileName + ".backup.json")
    }

    func load(validate: (Record) -> Bool = { _ in true }) throws -> [Record] {
        guard FileManager.default.fileExists(atPath: fileURL.path)
                || FileManager.default.fileExists(atPath: backupURL.path) else {
            return []
        }
        if let records = try? decodeComplete(from: fileURL, validate: validate) {
            return records
        }
        if let records = try? decodeComplete(from: backupURL, validate: validate) {
            return records
        }
        let primaryRecovered = (try? decodeRecordsIndividually(from: fileURL, validate: validate)) ?? []
        let backupRecovered = (try? decodeRecordsIndividually(from: backupURL, validate: validate)) ?? []
        let merged = Dictionary(
            (backupRecovered + primaryRecovered).map { ($0.id, $0) },
            uniquingKeysWith: { _, primary in primary }
        )
        if !merged.isEmpty { return Array(merged.values) }
        throw LockUStorageError.noRecoverableMetadata(fileURL.lastPathComponent)
    }

    func save(_ records: [Record]) throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: fileURL.path) {
            if manager.fileExists(atPath: backupURL.path) {
                try manager.removeItem(at: backupURL)
            }
            try manager.copyItem(at: fileURL, to: backupURL)
        }
        let data = try Self.encoder.encode(records)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func decodeComplete(
        from url: URL,
        validate: (Record) -> Bool
    ) throws -> [Record] {
        let data = try Data(contentsOf: url)
        return try Self.decoder.decode([Record].self, from: data).filter(validate)
    }

    private func decodeRecordsIndividually(
        from url: URL,
        validate: (Record) -> Bool
    ) throws -> [Record] {
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let array = object as? [Any] else { return [] }
        let recovered: [Record] = array.compactMap { element in
            guard JSONSerialization.isValidJSONObject(element),
                  let itemData = try? JSONSerialization.data(withJSONObject: element),
                  let record = try? Self.decoder.decode(Record.self, from: itemData),
                  validate(record) else { return nil }
            return record
        }
        return recovered
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
