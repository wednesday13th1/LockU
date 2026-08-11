import CoreGraphics
import Foundation

struct CodablePoint: Codable, Hashable, Sendable {
    var x: Double
    var y: Double

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

struct LockerPlacement: Codable, Hashable, Sendable {
    var position: CodablePoint
    var scale: Double
    var rotationDegrees: Double
    var isFlipped: Bool
    var zIndex: Int
}

struct LockerDecoration: Codable, Identifiable, Hashable, Sendable {
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
        appearance = try container.decodeIfPresent(LockerAppearanceSettings.self, forKey: .appearance) ?? .default
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

struct LockerAppearanceSettings: Codable, Equatable, Sendable {
    var collageStyle: LockerCollageStyle
    var frameStyle: LockerFrameStyle
    var filterStyle: LockerFilterStyle
    var featuredVideoMemoryID: UUID?
    var dailyVariationEnabled: Bool

    static let `default` = LockerAppearanceSettings(collageStyle: .balanced, frameStyle: .mixed, filterStyle: .clear, featuredVideoMemoryID: nil, dailyVariationEnabled: true)
}
