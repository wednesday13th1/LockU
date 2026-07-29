import Foundation
import UIKit

@MainActor
final class LegacyMigrationService {
    private enum Key {
        static let memories = "memoryStickers"
        static let decorations = "lockerDecorations"
        static let lockerColor = "lockerColor"
        static let lockerNumber = "lockerNumber"
        static let ownerName = "ownerName"
        static let background = "locku.locker.background.v1"
        static let completed = "locku.migration.v2.completed"

        static let all = [
            memories, decorations, lockerColor, lockerNumber, ownerName, background
        ]
    }

    private let defaults: UserDefaults
    private let memories: MemoryRepository
    private let decorations: DecorationRepository
    private let settings: LockerSettingsRepository
    private let backgrounds: BackgroundRepository

    init(
        defaults: UserDefaults = .standard,
        memories: MemoryRepository,
        decorations: DecorationRepository,
        settings: LockerSettingsRepository,
        backgrounds: BackgroundRepository
    ) {
        self.defaults = defaults
        self.memories = memories
        self.decorations = decorations
        self.settings = settings
        self.backgrounds = backgrounds
    }

    func migrateIfNeeded() throws {
        guard !defaults.bool(forKey: Key.completed) else { return }
        let existingKeys = Key.all.filter { defaults.object(forKey: $0) != nil }
        guard !existingKeys.isEmpty else {
            defaults.set(true, forKey: Key.completed)
            return
        }

        try migrateImageArray(forKey: Key.memories) { image, date in
            try memories.importLegacyImage(image, createdAt: date)
        }
        try migrateImageArray(forKey: Key.decorations) { image, date in
            try decorations.add(image: image, createdAt: date)
        }

        var migratedSettings = settings.settings
        if let value = defaults.string(forKey: Key.lockerColor) {
            migratedSettings.lockerColorHex = value
        }
        if let value = defaults.string(forKey: Key.lockerNumber) {
            migratedSettings.lockerNumber = value
        } else if defaults.object(forKey: Key.lockerNumber) != nil {
            migratedSettings.lockerNumber = String(defaults.integer(forKey: Key.lockerNumber))
        }
        if let value = defaults.string(forKey: Key.ownerName) {
            migratedSettings.ownerName = value
        }
        try settings.update(migratedSettings)

        if let backgroundData = extractImageData(defaults.object(forKey: Key.background)),
           let image = UIImage(data: backgroundData) {
            try backgrounds.save(image)
        } else if defaults.object(forKey: Key.background) != nil {
            throw LegacyMigrationError.unreadableValue(Key.background)
        }

        existingKeys.forEach(defaults.removeObject(forKey:))
        defaults.set(true, forKey: Key.completed)
    }

    private func migrateImageArray(
        forKey key: String,
        consume: (UIImage, Date) throws -> Void
    ) throws {
        guard let raw = defaults.object(forKey: key) else { return }
        let values: [Any]
        if let array = raw as? [Any] {
            values = array
        } else if let data = raw as? Data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            values = json
        } else {
            throw LegacyMigrationError.unreadableValue(key)
        }

        for value in values {
            guard let imageData = extractImageData(value),
                  let image = UIImage(data: imageData) else {
                throw LegacyMigrationError.unreadableValue(key)
            }
            let date = extractDate(value) ?? .now
            try consume(image, date)
        }
    }

    private func extractImageData(_ value: Any?) -> Data? {
        if let data = value as? Data { return data }
        guard let dictionary = value as? [String: Any] else { return nil }
        for key in ["imageData", "compositeImageData", "frontImageData", "rearImageData"] {
            if let data = dictionary[key] as? Data { return data }
            if let encoded = dictionary[key] as? String,
               let data = Data(base64Encoded: encoded) { return data }
        }
        return nil
    }

    private func extractDate(_ value: Any) -> Date? {
        guard let dictionary = value as? [String: Any] else { return nil }
        if let date = dictionary["createdAt"] as? Date { return date }
        if let interval = dictionary["createdAt"] as? TimeInterval {
            return Date(timeIntervalSince1970: interval)
        }
        if let text = dictionary["createdAt"] as? String {
            return ISO8601DateFormatter().date(from: text)
        }
        return nil
    }
}

enum LegacyMigrationError: LocalizedError {
    case unreadableValue(String)

    var errorDescription: String? {
        switch self {
        case .unreadableValue(let key):
            return "旧データ「\(key)」を安全に読み込めなかったため、元データを残しました。"
        }
    }
}
