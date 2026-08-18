import Combine
import Foundation

@MainActor
final class LockerSettingsRepository: ObservableObject {
    @Published private(set) var settings: LockerSettings = .default

    private let fileURL: URL
    private let backupURL: URL
    var hasStoredData: Bool { FileManager.default.fileExists(atPath: fileURL.path) || FileManager.default.fileExists(atPath: backupURL.path) }

    init(paths: LockUPaths) {
        fileURL = paths.root.appendingPathComponent("locker-settings.json")
        backupURL = paths.root.appendingPathComponent("locker-settings.backup.json")
    }

    func reload() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path)
                || FileManager.default.fileExists(atPath: backupURL.path) else {
            settings = .default
            return
        }
        if let loaded = decode(at: fileURL) ?? decode(at: backupURL) {
            settings = loaded
        } else {
            throw LockUStorageError.noRecoverableMetadata(fileURL.lastPathComponent)
        }
    }

    func update(_ newSettings: LockerSettings) throws {
        var sanitized = newSettings
        sanitized.doorOpenProgress = min(1, max(0, sanitized.doorOpenProgress.isFinite ? sanitized.doorOpenProgress : 0))
        let data = try JSONEncoder().encode(sanitized)
        let manager = FileManager.default
        if manager.fileExists(atPath: fileURL.path) {
            if manager.fileExists(atPath: backupURL.path) {
                try manager.removeItem(at: backupURL)
            }
            try manager.copyItem(at: fileURL, to: backupURL)
        }
        try data.write(to: fileURL, options: [.atomic])
        settings = sanitized
    }

    private func decode(at url: URL) -> LockerSettings? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LockerSettings.self, from: data)
    }
}
