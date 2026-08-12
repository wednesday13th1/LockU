import Foundation

nonisolated struct DailyFilm: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let subtitle: String?
    let version: Int
    let exposure: Double
    let contrast: Double
    let saturation: Double
    let temperature: Double
    let tint: Double
    let highlights: Double
    let shadows: Double
    let fade: Double
    let grain: Double
    let vignette: Double
    let bloom: Double
    let sharpness: Double
}
