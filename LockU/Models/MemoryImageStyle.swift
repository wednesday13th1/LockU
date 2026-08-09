import Foundation

enum MemoryImageStyle: String, CaseIterable, Identifiable, Sendable {
    case original
    case cutout

    var id: String { rawValue }
}

enum MemoryImageFormat: String, Codable, Sendable {
    case jpeg
    case png
}

enum MemoryPresentationStyle: String, Codable, CaseIterable, Sendable {
    case digicam, cheki, cutout, photobooth
}
