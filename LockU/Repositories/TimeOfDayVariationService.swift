import Foundation

enum LockerTimeOfDay: String, Codable, CaseIterable, Sendable {
    case morning
    case day
    case afterSchool
    case night
}

struct LockerTimeOfDayResolver {
    func resolve(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> LockerTimeOfDay {
        switch calendar.component(.hour, from: date) {
        case 6..<12: return .morning
        case 12..<17: return .day
        case 17..<21: return .afterSchool
        default: return .night
        }
    }
}

struct TimeOfDayVariationResult: Equatable, Sendable {
    let currentTimeOfDay: LockerTimeOfDay
    let emphasizedMemoryIDs: [UUID]
    let resurfacedMemoryID: UUID?
    let variationSeed: UInt64
    let generatedAt: Date
}

struct TimeOfDayVariationService {
    private let resolver: LockerTimeOfDayResolver
    private let resurfacingService: MemoryResurfacingService

    init(
        resolver: LockerTimeOfDayResolver = LockerTimeOfDayResolver(),
        resurfacingService: MemoryResurfacingService = MemoryResurfacingService()
    ) {
        self.resolver = resolver
        self.resurfacingService = resurfacingService
    }

    func variation(
        for date: Date,
        memories: [MemoryRecord],
        lockerIdentifier: String,
        overridingTimeOfDay: LockerTimeOfDay? = nil,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TimeOfDayVariationResult {
        let timeOfDay = overridingTimeOfDay ?? resolver.resolve(for: date, calendar: calendar)
        let seed = stableSeed(for: date, timeOfDay: timeOfDay, lockerIdentifier: lockerIdentifier, memories: memories, calendar: calendar)
        let emphasized: [UUID]
        let resurfaced: UUID?

        switch timeOfDay {
        case .morning:
            emphasized = recentCandidate(for: date, memories: memories, prefersToday: false, calendar: calendar).map { [$0.id] } ?? []
            resurfaced = nil
        case .day:
            emphasized = []
            resurfaced = nil
        case .afterSchool:
            emphasized = recentCandidate(for: date, memories: memories, prefersToday: true, calendar: calendar).map { [$0.id] } ?? []
            resurfaced = nil
        case .night:
            let candidate = resurfacingService.candidate(for: date, from: memories, calendar: calendar)?.memory
            emphasized = candidate.map { [$0.id] } ?? []
            resurfaced = candidate?.id
        }

        return TimeOfDayVariationResult(
            currentTimeOfDay: timeOfDay,
            emphasizedMemoryIDs: emphasized,
            resurfacedMemoryID: resurfaced,
            variationSeed: seed,
            generatedAt: intervalStart(for: date, timeOfDay: timeOfDay, calendar: calendar)
        )
    }

    private func recentCandidate(
        for date: Date,
        memories: [MemoryRecord],
        prefersToday: Bool,
        calendar: Calendar
    ) -> MemoryRecord? {
        let today = calendar.startOfDay(for: date)
        let sorted = memories.sorted { $0.memoryDate > $1.memoryDate }
        if prefersToday, let todayMemory = sorted.first(where: { calendar.isDate($0.memoryDate, inSameDayAs: today) }) {
            return todayMemory
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           let yesterdayMemory = sorted.first(where: { calendar.isDate($0.memoryDate, inSameDayAs: yesterday) }) {
            return yesterdayMemory
        }
        guard let recentStart = calendar.date(byAdding: .day, value: -7, to: today) else { return nil }
        return sorted.first { memory in
            let memoryDay = calendar.startOfDay(for: memory.memoryDate)
            return memoryDay >= recentStart && memoryDay <= today
        }
    }

    private func intervalStart(for date: Date, timeOfDay: LockerTimeOfDay, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: date)
        let hour: Int
        switch timeOfDay {
        case .morning: hour = 6
        case .day: hour = 12
        case .afterSchool: hour = 17
        case .night:
            if calendar.component(.hour, from: date) < 6 {
                let previousDay = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                return calendar.date(bySettingHour: 21, minute: 0, second: 0, of: previousDay) ?? previousDay
            }
            hour = 21
        }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today) ?? today
    }

    private func stableSeed(
        for date: Date,
        timeOfDay: LockerTimeOfDay,
        lockerIdentifier: String,
        memories: [MemoryRecord],
        calendar: Calendar
    ) -> UInt64 {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%04d%02d%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
        let memoryComponent = memories.map(\.id.uuidString).sorted().joined(separator: "|")
        return fnv1a64("\(day)|\(timeOfDay.rawValue)|\(lockerIdentifier)|\(memoryComponent)")
    }

    private func fnv1a64(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}
