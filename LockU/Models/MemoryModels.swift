import Foundation

enum CaptureMode: String, Codable, Sendable {
    case photoLibrary
    case camera
    case legacy
}

struct WeatherSnapshot: Codable, Hashable, Sendable {
    var summary: String
    var temperatureCelsius: Double?
}

struct MemoryRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let imageFileName: String
    var filterID: String?
    var weather: WeatherSnapshot?
    var captureMode: CaptureMode
    var imageFormat: MemoryImageFormat?
    var isSubjectCutout: Bool?
}
