import CoreGraphics
import Foundation

nonisolated enum LockerMemoryLayout {
    /// Number of static photo frames in the competition Locker Home layout.
    static let photoSlotCount = 7
    static let livingMemorySlotCount = 1

    static var totalVisibleSlotCount: Int {
        photoSlotCount + livingMemorySlotCount
    }
}

nonisolated struct CodablePoint: Codable, Hashable, Sendable {
    var x: Double
    var y: Double

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

nonisolated struct LockerPlacement: Codable, Hashable, Sendable {
    var position: CodablePoint
    var scale: Double
    var rotationDegrees: Double
    var isFlipped: Bool
    var zIndex: Int
}

nonisolated enum LockerTextFontStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case handwritten, casual, clean, mono
    var id: String { rawValue }
}

nonisolated enum LockerTextColorStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case charcoal, navy, blue, pink, white, yellow
    var id: String { rawValue }
}

nonisolated enum LockerDrawingColorStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case charcoal, navy, blue, pink, white, yellow
    var id: String { rawValue }
}

nonisolated struct LockerDrawingStroke: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var points: [CodablePoint]
    var colorStyle: LockerDrawingColorStyle
    var lineWidth: Double
}

nonisolated struct LockerDrawingDecoration: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var strokes: [LockerDrawingStroke]
    var position: CodablePoint
    var scale: Double
    var rotationDegrees: Double
    var zIndex: Int
    let createdAt: Date
}

nonisolated struct LockerTextDecoration: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var text: String
    var normalizedX: Double
    var normalizedY: Double
    var scale: Double
    var rotationDegrees: Double
    var zIndex: Int
    var fontStyle: LockerTextFontStyle
    var colorStyle: LockerTextColorStyle
    let createdAt: Date

    init(
        id: UUID, text: String, normalizedX: Double, normalizedY: Double,
        scale: Double, rotationDegrees: Double, zIndex: Int,
        fontStyle: LockerTextFontStyle = .handwritten,
        colorStyle: LockerTextColorStyle = .charcoal,
        createdAt: Date
    ) {
        self.id = id
        self.text = text
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.zIndex = zIndex
        self.fontStyle = fontStyle
        self.colorStyle = colorStyle
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, normalizedX, normalizedY, scale, rotationDegrees
        case zIndex, fontStyle, colorStyle, colorHex, createdAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        text = try values.decode(String.self, forKey: .text)
        normalizedX = try values.decode(Double.self, forKey: .normalizedX)
        normalizedY = try values.decode(Double.self, forKey: .normalizedY)
        scale = try values.decodeIfPresent(Double.self, forKey: .scale) ?? 1
        rotationDegrees = try values.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? 0
        zIndex = try values.decodeIfPresent(Int.self, forKey: .zIndex) ?? 30
        fontStyle = try values.decodeIfPresent(LockerTextFontStyle.self, forKey: .fontStyle) ?? .handwritten
        if let savedStyle = try values.decodeIfPresent(LockerTextColorStyle.self, forKey: .colorStyle) {
            colorStyle = savedStyle
        } else {
            colorStyle = Self.migratedColor(from: try values.decodeIfPresent(String.self, forKey: .colorHex))
        }
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(text, forKey: .text)
        try values.encode(normalizedX, forKey: .normalizedX)
        try values.encode(normalizedY, forKey: .normalizedY)
        try values.encode(scale, forKey: .scale)
        try values.encode(rotationDegrees, forKey: .rotationDegrees)
        try values.encode(zIndex, forKey: .zIndex)
        try values.encode(fontStyle, forKey: .fontStyle)
        try values.encode(colorStyle, forKey: .colorStyle)
        try values.encode(createdAt, forKey: .createdAt)
    }

    private static func migratedColor(from hex: String?) -> LockerTextColorStyle {
        switch hex?.uppercased() {
        case "#162636": return .navy
        case "#007AFF", "#0A84FF": return .blue
        case "#FF2D55", "#FF375F": return .pink
        case "#FFFFFF": return .white
        case "#FFD60A", "#FFCC00": return .yellow
        default: return .charcoal
        }
    }
}

nonisolated enum LockerMemoryPlacementKind: String, Codable, Sendable { case automatic, userAdded }

nonisolated struct LockerMemoryPlacement: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let memoryID: UUID
    var normalizedX: Double
    var normalizedY: Double
    var scale: Double
    var rotationDegrees: Double
    var zIndex: Int
    let kind: LockerMemoryPlacementKind
    let createdAt: Date
}

nonisolated struct LockerCanvasMetadata: Codable, Identifiable, Hashable, Sendable {
    static let recordID = UUID(uuidString: "CB786E9A-61C8-4C2A-A654-701BE0F547C8")!
    let id: UUID
    var drawingFileName: String?
    var drawingReferenceWidth: Double?
    var drawingReferenceHeight: Double?
    var texts: [LockerTextDecoration]
    var memoryPlacements: [LockerMemoryPlacement]
    var drawingDecorations: [LockerDrawingDecoration]

    init(
        id: UUID, drawingFileName: String?, drawingReferenceWidth: Double?,
        drawingReferenceHeight: Double?, texts: [LockerTextDecoration],
        memoryPlacements: [LockerMemoryPlacement],
        drawingDecorations: [LockerDrawingDecoration] = []
    ) {
        self.id = id
        self.drawingFileName = drawingFileName
        self.drawingReferenceWidth = drawingReferenceWidth
        self.drawingReferenceHeight = drawingReferenceHeight
        self.texts = texts
        self.memoryPlacements = memoryPlacements
        self.drawingDecorations = drawingDecorations
    }

    private enum CodingKeys: String, CodingKey {
        case id, drawingFileName, drawingReferenceWidth, drawingReferenceHeight
        case texts, memoryPlacements, drawingDecorations
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? Self.recordID
        drawingFileName = try values.decodeIfPresent(String.self, forKey: .drawingFileName)
        drawingReferenceWidth = try values.decodeIfPresent(Double.self, forKey: .drawingReferenceWidth)
        drawingReferenceHeight = try values.decodeIfPresent(Double.self, forKey: .drawingReferenceHeight)
        texts = try values.decodeIfPresent([LockerTextDecoration].self, forKey: .texts) ?? []
        memoryPlacements = try values.decodeIfPresent([LockerMemoryPlacement].self, forKey: .memoryPlacements) ?? []
        drawingDecorations = try values.decodeIfPresent([LockerDrawingDecoration].self, forKey: .drawingDecorations) ?? []
    }

    static let empty = LockerCanvasMetadata(id: recordID, drawingFileName: nil, drawingReferenceWidth: nil, drawingReferenceHeight: nil, texts: [], memoryPlacements: [], drawingDecorations: [])
}

nonisolated struct LockerDecoration: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let imageFileName: String
    var position: CodablePoint
    var scale: Double
    var rotationDegrees: Double
    var isFlipped: Bool
    var zIndex: Int

    var placement: LockerPlacement {
        get { LockerPlacement(position: position, scale: scale, rotationDegrees: rotationDegrees, isFlipped: isFlipped, zIndex: zIndex) }
        set { position = newValue.position; scale = newValue.scale; rotationDegrees = newValue.rotationDegrees; isFlipped = newValue.isFlipped; zIndex = newValue.zIndex }
    }
}

struct LockerSettings: Codable, Equatable, Sendable {
    var lockerColorHex: String
    var lockerNumber: String
    var ownerName: String
    var appearance: LockerAppearanceSettings

    enum CodingKeys: String, CodingKey {
        case lockerColorHex, lockerNumber, ownerName, appearance
    }

    init(lockerColorHex: String, lockerNumber: String, ownerName: String, appearance: LockerAppearanceSettings = .default) {
        self.lockerColorHex = lockerColorHex
        self.lockerNumber = lockerNumber
        self.ownerName = ownerName
        self.appearance = appearance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lockerColorHex = try container.decode(String.self, forKey: .lockerColorHex)
        lockerNumber = try container.decode(String.self, forKey: .lockerNumber)
        ownerName = try container.decode(String.self, forKey: .ownerName)
        appearance = (try? container.decodeIfPresent(LockerAppearanceSettings.self, forKey: .appearance)) ?? .default
    }

    static let `default` = LockerSettings(
        lockerColorHex: "#7A97A6",
        lockerNumber: "24",
        ownerName: "My"
    )
}

enum LockerCollageStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case balanced, casual, polaroid, digicam
    var id: String { rawValue }
    var title: String {
        switch self { case .balanced: "バランス"; case .casual: "ラフ"; case .polaroid: "チェキ"; case .digicam: "デジカメ" }
    }
}

enum LockerFrameStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case mixed, polaroid, thinWhite, borderless
    var id: String { rawValue }
    var title: String {
        switch self { case .mixed: "ミックス"; case .polaroid: "チェキ"; case .thinWhite: "白フチ"; case .borderless: "フチなし" }
    }
}

enum LockerFilterStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case clear, digicam, film, aoharu, soft
    var id: String { rawValue }
    var title: String {
        switch self { case .clear: "クリア"; case .digicam: "デジカメ"; case .film: "フィルム"; case .aoharu: "アオハル"; case .soft: "ソフト" }
    }
}

enum LockerBackgroundStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case clearBlue
    case softSky
    case warmSunset
    case paleCream
    case coolGray
    case fadedSchoolBlue

    var id: String { rawValue }
    var title: String {
        switch self {
        case .clearBlue: "青空"
        case .softSky: "やわらかい空"
        case .warmSunset: "夕焼け"
        case .paleCream: "クリーム"
        case .coolGray: "クールグレー"
        case .fadedSchoolBlue: "スクールブルー"
        }
    }
}

enum LockerItemTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case blush
    case blue
    case sage
    case aoharu

    var id: String { rawValue }
    var title: String {
        switch self { case .blush: "スイート"; case .blue: "ブルー"; case .sage: "セージ"; case .aoharu: "アオハル" }
    }
}

struct LockerAppearanceSettings: Codable, Equatable, Sendable {
    var collageStyle: LockerCollageStyle
    var frameStyle: LockerFrameStyle
    var filterStyle: LockerFilterStyle
    var featuredVideoMemoryID: UUID?
    var dailyVariationEnabled: Bool
    var backgroundStyle: LockerBackgroundStyle
    var itemTheme: LockerItemTheme

    enum CodingKeys: String, CodingKey {
        case collageStyle, frameStyle, filterStyle, featuredVideoMemoryID, dailyVariationEnabled, backgroundStyle, itemTheme
    }

    init(collageStyle: LockerCollageStyle, frameStyle: LockerFrameStyle, filterStyle: LockerFilterStyle, featuredVideoMemoryID: UUID?, dailyVariationEnabled: Bool, backgroundStyle: LockerBackgroundStyle = .clearBlue, itemTheme: LockerItemTheme = .aoharu) {
        self.collageStyle = collageStyle
        self.frameStyle = frameStyle
        self.filterStyle = filterStyle
        self.featuredVideoMemoryID = featuredVideoMemoryID
        self.dailyVariationEnabled = dailyVariationEnabled
        self.backgroundStyle = backgroundStyle
        self.itemTheme = itemTheme
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        collageStyle = (try? container.decodeIfPresent(LockerCollageStyle.self, forKey: .collageStyle)) ?? .balanced
        frameStyle = (try? container.decodeIfPresent(LockerFrameStyle.self, forKey: .frameStyle)) ?? .mixed
        filterStyle = (try? container.decodeIfPresent(LockerFilterStyle.self, forKey: .filterStyle)) ?? .clear
        featuredVideoMemoryID = try container.decodeIfPresent(UUID.self, forKey: .featuredVideoMemoryID)
        dailyVariationEnabled = try container.decodeIfPresent(Bool.self, forKey: .dailyVariationEnabled) ?? true
        backgroundStyle = (try? container.decodeIfPresent(LockerBackgroundStyle.self, forKey: .backgroundStyle)) ?? .clearBlue
        itemTheme = (try? container.decodeIfPresent(LockerItemTheme.self, forKey: .itemTheme)) ?? .aoharu
    }

    static let `default` = LockerAppearanceSettings(collageStyle: .balanced, frameStyle: .mixed, filterStyle: .clear, featuredVideoMemoryID: nil, dailyVariationEnabled: true, backgroundStyle: .clearBlue, itemTheme: .aoharu)
}
