import Foundation

nonisolated enum MemoryImageStyle: String, CaseIterable, Identifiable, Sendable {
    case original
    case cutout

    var id: String { rawValue }
}

nonisolated enum MemoryImageFormat: String, Codable, Sendable {
    case jpeg
    case png
}

nonisolated enum MemoryPresentationStyle: String, Codable, CaseIterable, Sendable {
    case digicam, cheki, cutout, photobooth
}
