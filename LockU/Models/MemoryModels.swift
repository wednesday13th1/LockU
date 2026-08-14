import Foundation

nonisolated enum CaptureMode: String, Codable, Sendable {
    case photoLibrary
    case camera
    case legacy
}

nonisolated enum MemoryOrigin: String, Codable, Sendable {
    case dailyCapture
    case seedImport
    case legacy
}

nonisolated enum MemoryMoodEmoji: String, Codable, CaseIterable, Identifiable, Sendable {
    case laugh = "😆"
    case love = "🫶"
    case calm = "😌"
    case emotional = "🥹"
    case sad = "😭"
    case tired = "🥱"
    case frustrated = "😤"
    case fire = "🔥"
    case growth = "🌱"
    case sparkle = "✨"

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .laugh: "嬉しい"
        case .love: "大切"
        case .calm: "安心"
        case .emotional: "胸がいっぱい"
        case .sad: "泣きたい"
        case .tired: "疲れた"
        case .frustrated: "悔しい"
        case .fire: "頑張った"
        case .growth: "少し成長"
        case .sparkle: "きらめいた"
        }
    }
}

nonisolated struct MemoryReflection: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let memoryID: UUID
    let text: String
    let createdAt: Date
}

nonisolated enum MemoryReflectionPolicy {
    static let maximumLength = 150

    static func normalized(_ text: String) throws -> String? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        guard normalized.count <= maximumLength else {
            throw MemoryReflectionError.textTooLong
        }
        return normalized
    }
}

nonisolated enum MemoryReflectionError: LocalizedError {
    case textTooLong

    var errorDescription: String? {
        switch self {
        case .textTooLong:
            "振り返りは\(MemoryReflectionPolicy.maximumLength)文字以内で入力してください。"
        }
    }
}

nonisolated struct WeatherSnapshot: Codable, Hashable, Sendable {
    var summary: String
    var temperatureCelsius: Double?
}

nonisolated struct MemoryRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let imageFileName: String
    var filterID: String?
    var weather: WeatherSnapshot?
    var captureMode: CaptureMode
    var imageFormat: MemoryImageFormat?
    var isSubjectCutout: Bool?
    var presentationStyle: MemoryPresentationStyle?
    var dailyFilmID: String?
    var dailyFilmName: String?
    var dailyFilmVersion: Int?
    var frontImageFileName: String?
    var backImageFileName: String?
    var videoFileName: String?
    var videoThumbnailFileName: String?
    var memoryNote: String?
    var moodEmoji: String?
    var dailyFilmIdentifier: String?
    var lastRevisitedAt: Date?
    var revisitCount: Int
    var origin: MemoryOrigin
    var importedAt: Date?

    var memoryDate: Date { createdAt }
    var isDualCameraMemory: Bool {
        frontImageFileName != nil && backImageFileName != nil
    }

    init(
        id: UUID,
        createdAt: Date,
        imageFileName: String,
        filterID: String? = nil,
        weather: WeatherSnapshot? = nil,
        captureMode: CaptureMode,
        imageFormat: MemoryImageFormat? = nil,
        isSubjectCutout: Bool? = nil,
        presentationStyle: MemoryPresentationStyle? = nil,
        dailyFilmID: String? = nil,
        dailyFilmName: String? = nil,
        dailyFilmVersion: Int? = nil,
        frontImageFileName: String? = nil,
        backImageFileName: String? = nil,
        videoFileName: String? = nil,
        videoThumbnailFileName: String? = nil,
        memoryNote: String? = nil,
        moodEmoji: String? = nil,
        dailyFilmIdentifier: String? = nil,
        lastRevisitedAt: Date? = nil,
        revisitCount: Int = 0
        , origin: MemoryOrigin = .dailyCapture
        , importedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.imageFileName = imageFileName
        self.filterID = filterID
        self.weather = weather
        self.captureMode = captureMode
        self.imageFormat = imageFormat
        self.isSubjectCutout = isSubjectCutout
        self.presentationStyle = presentationStyle
        self.dailyFilmID = dailyFilmID
        self.dailyFilmName = dailyFilmName
        self.dailyFilmVersion = dailyFilmVersion
        self.frontImageFileName = frontImageFileName
        self.backImageFileName = backImageFileName
        self.videoFileName = videoFileName
        self.videoThumbnailFileName = videoThumbnailFileName
        self.memoryNote = memoryNote
        self.moodEmoji = moodEmoji
        self.dailyFilmIdentifier = dailyFilmIdentifier ?? dailyFilmID
        self.lastRevisitedAt = lastRevisitedAt
        self.revisitCount = max(0, revisitCount)
        self.origin = origin
        self.importedAt = importedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, imageFileName, filterID, weather, captureMode, imageFormat, isSubjectCutout, presentationStyle
        case dailyFilmID, dailyFilmName, dailyFilmVersion, frontImageFileName, backImageFileName
        case videoFileName, videoThumbnailFileName, memoryNote, moodEmoji, dailyFilmIdentifier, lastRevisitedAt, revisitCount
        case origin, importedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        imageFileName = try container.decode(String.self, forKey: .imageFileName)
        filterID = try container.decodeIfPresent(String.self, forKey: .filterID)
        weather = try container.decodeIfPresent(WeatherSnapshot.self, forKey: .weather)
        captureMode = try container.decodeIfPresent(CaptureMode.self, forKey: .captureMode) ?? .legacy
        imageFormat = try container.decodeIfPresent(MemoryImageFormat.self, forKey: .imageFormat)
        isSubjectCutout = try container.decodeIfPresent(Bool.self, forKey: .isSubjectCutout)
        presentationStyle = try container.decodeIfPresent(MemoryPresentationStyle.self, forKey: .presentationStyle)
        dailyFilmID = try container.decodeIfPresent(String.self, forKey: .dailyFilmID)
        dailyFilmName = try container.decodeIfPresent(String.self, forKey: .dailyFilmName)
        dailyFilmVersion = try container.decodeIfPresent(Int.self, forKey: .dailyFilmVersion)
        frontImageFileName = try container.decodeIfPresent(String.self, forKey: .frontImageFileName)
        backImageFileName = try container.decodeIfPresent(String.self, forKey: .backImageFileName)
        videoFileName = try container.decodeIfPresent(String.self, forKey: .videoFileName)
        videoThumbnailFileName = try container.decodeIfPresent(String.self, forKey: .videoThumbnailFileName)
        memoryNote = try container.decodeIfPresent(String.self, forKey: .memoryNote)
        moodEmoji = try container.decodeIfPresent(String.self, forKey: .moodEmoji)
        dailyFilmIdentifier = try container.decodeIfPresent(String.self, forKey: .dailyFilmIdentifier) ?? dailyFilmID
        lastRevisitedAt = try container.decodeIfPresent(Date.self, forKey: .lastRevisitedAt)
        revisitCount = max(0, try container.decodeIfPresent(Int.self, forKey: .revisitCount) ?? 0)
        origin = try container.decodeIfPresent(MemoryOrigin.self, forKey: .origin) ?? (captureMode == .legacy ? .legacy : .dailyCapture)
        importedAt = try container.decodeIfPresent(Date.self, forKey: .importedAt)
    }

}
