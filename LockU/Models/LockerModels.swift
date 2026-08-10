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

    static let `default` = LockerSettings(
        lockerColorHex: "#7A97A6",
        lockerNumber: "24",
        ownerName: "My"
    )
}
