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

nonisolated struct LockerTextDecoration: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var text: String
    var normalizedX: Double
    var normalizedY: Double
    var scale: Double
    var rotationDegrees: Double
    let createdAt: Date
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

    static let empty = LockerCanvasMetadata(id: recordID, drawingFileName: nil, drawingReferenceWidth: nil, drawingReferenceHeight: nil, texts: [], memoryPlacements: [])
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
    var title: String { rawValue.capitalized }
}

enum LockerFrameStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case mixed, polaroid, thinWhite, borderless
    var id: String { rawValue }
    var title: String {
        switch self { case .mixed: "Mixed"; case .polaroid: "Polaroid"; case .thinWhite: "Thin White"; case .borderless: "Borderless" }
    }
}

enum LockerFilterStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case clear, digicam, film, aoharu, soft
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
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
        case .clearBlue: "Clear Blue"
        case .softSky: "Soft Sky"
        case .warmSunset: "Warm Sunset"
        case .paleCream: "Pale Cream"
        case .coolGray: "Cool Gray"
        case .fadedSchoolBlue: "Faded School Blue"
        }
    }
}

enum LockerItemTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case blush
    case blue
    case sage
    case aoharu

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
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
