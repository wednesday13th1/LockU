import Foundation

enum LockerGrowthStage: Int, CaseIterable, Equatable, Sendable {
    case fresh
    case familiar
    case livedIn
    case personal
    case nostalgic

    init(activeDays: Int) {
        switch activeDays {
        case ..<3: self = .fresh
        case 3..<7: self = .familiar
        case 7..<14: self = .livedIn
        case 14..<30: self = .personal
        default: self = .nostalgic
        }
    }

    var decorationLimit: Int {
        switch self {
        case .fresh: 0
        case .familiar: 1
        case .livedIn: 2
        case .personal: 4
        case .nostalgic: 5
        }
    }
}

enum LockerGrowthDecorationType: String, Equatable, Sendable {
    case tape
    case sticker
    case miniPhoto
    case memo
    case wear
    case tag
}

enum LockerDecorationRole: String, Equatable, Sendable {
    case decorative
    case resurfacing
}

struct LockerGrowthDecoration: Identifiable, Equatable, Sendable {
    let id: String
    let type: LockerGrowthDecorationType
    let role: LockerDecorationRole
    let normalizedPosition: CodablePoint
    let rotation: Double
    let scale: Double
    let styleID: String
}

struct LockerGrowthState: Equatable, Sendable {
    let stage: LockerGrowthStage
    let activeDays: Int
    let decorations: [LockerGrowthDecoration]

    static let fresh = LockerGrowthState(stage: .fresh, activeDays: 0, decorations: [])
}

struct LockerGrowthGenerator {
    private let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func state(memories: [MemoryRecord]) -> LockerGrowthState {
        let activeDates = Set(memories.map { calendar.startOfDay(for: $0.memoryDate) })
        let activeDays = activeDates.count
        let stage = LockerGrowthStage(activeDays: activeDays)
        guard let firstDay = activeDates.min(), stage.decorationLimit > 0 else {
            return LockerGrowthState(stage: stage, activeDays: activeDays, decorations: [])
        }

        let seed = stableSeed(dayIdentifier(for: firstDay))
        let decorations = catalog(seed: seed).prefix(stage.decorationLimit)
        return LockerGrowthState(stage: stage, activeDays: activeDays, decorations: Array(decorations))
    }

    private func catalog(seed: UInt64) -> [LockerGrowthDecoration] {
        let mirror = (seed & 1) == 1
        let leftX = mirror ? 0.84 : 0.14
        let rightX = mirror ? 0.16 : 0.86
        return [
            LockerGrowthDecoration(
                id: "familiar-tape",
                type: .tape,
                role: .decorative,
                normalizedPosition: CodablePoint(x: leftX, y: 0.22),
                rotation: signed(seed, limit: 6),
                scale: 0.82,
                styleID: "matte-tape"
            ),
            LockerGrowthDecoration(
                id: "lived-sticker",
                type: .sticker,
                role: .decorative,
                normalizedPosition: CodablePoint(x: rightX, y: 0.33),
                rotation: signed(seed >> 7, limit: 4),
                scale: 0.78,
                styleID: "paper-mark"
            ),
            LockerGrowthDecoration(
                id: "personal-photo",
                type: .miniPhoto,
                role: .resurfacing,
                normalizedPosition: CodablePoint(x: leftX, y: 0.60),
                rotation: signed(seed >> 13, limit: 5),
                scale: 0.90,
                styleID: "sky-print"
            ),
            LockerGrowthDecoration(
                id: "personal-memo",
                type: .memo,
                role: .resurfacing,
                normalizedPosition: CodablePoint(x: rightX, y: 0.66),
                rotation: signed(seed >> 19, limit: 3),
                scale: 0.84,
                styleID: "hand-note"
            ),
            LockerGrowthDecoration(
                id: "nostalgic-wear",
                type: .wear,
                role: .decorative,
                normalizedPosition: CodablePoint(x: mirror ? 0.64 : 0.36, y: 0.90),
                rotation: signed(seed >> 23, limit: 4),
                scale: 0.88,
                styleID: "shelf-trace"
            )
        ]
    }

    private func signed(_ seed: UInt64, limit: Double) -> Double {
        let unit = Double(seed % 10_001) / 5_000 - 1
        return max(-limit, min(limit, unit * limit))
    }

    private func stableSeed(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    private func dayIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
