import Combine
import Foundation

nonisolated protocol LockUClock {
    @MainActor
    var now: Date { get }
}

nonisolated struct SystemLockUClock: LockUClock {
    var now: Date { .now }
}

nonisolated struct FixedLockUClock: LockUClock {
    let now: Date
}

nonisolated enum LockUDemoTimePreset: String, CaseIterable, Identifiable {
    case live
    case morning
    case afterSchool
    case night
    case revisitFuture

    var id: String { rawValue }
    var title: String {
        switch self {
        case .live: "Live"
        case .morning: "Morning"
        case .afterSchool: "After School"
        case .night: "Night"
        case .revisitFuture: "+37 Days · Night"
        }
    }
}

@MainActor
final class LockUDemoClock: ObservableObject, LockUClock {
    @Published private(set) var preset: LockUDemoTimePreset = .live
    @Published private(set) var fixedNow: Date?

    private let systemClock: SystemLockUClock
    private let calendar: Calendar

    init(systemClock: SystemLockUClock, calendar: Calendar) {
        self.systemClock = systemClock
        self.calendar = calendar
    }

    convenience init() {
        self.init(systemClock: SystemLockUClock(), calendar: .autoupdatingCurrent)
    }

    var now: Date { fixedNow ?? systemClock.now }
    var isLive: Bool { preset == .live }

    func select(_ preset: LockUDemoTimePreset, memories: [MemoryRecord]) {
        self.preset = preset
        let liveNow = systemClock.now
        switch preset {
        case .live:
            fixedNow = nil
        case .morning:
            fixedNow = time(hour: 8, on: liveNow)
        case .afterSchool:
            fixedNow = time(hour: 18, on: liveNow)
        case .night:
            fixedNow = time(hour: 22, on: liveNow)
        case .revisitFuture:
            let reference = memories
                .filter { $0.memoryDate <= liveNow }
                .max { $0.memoryDate < $1.memoryDate }?
                .memoryDate ?? liveNow
            let future = calendar.date(byAdding: .day, value: 37, to: reference) ?? liveNow
            fixedNow = time(hour: 22, on: future)
        }
    }

    private func time(hour: Int, on date: Date) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
    }
}

nonisolated struct RevisitPresentation: Identifiable, Equatable, Sendable {
    let memoryID: UUID
    let memory: MemoryRecord
    let reason: MemoryResurfacingReason
    let capturedAt: Date
    let daysAgo: Int
    let eyebrowText: String
    let relativeDateText: String

    var id: UUID { memoryID }
}

@MainActor
final class RevisitCoordinator: ObservableObject {
    @Published private(set) var presentation: RevisitPresentation?

    private let resurfacingService: MemoryResurfacingService
    private let calendar: Calendar

    init(resurfacingService: MemoryResurfacingService, calendar: Calendar) {
        self.resurfacingService = resurfacingService
        self.calendar = calendar
    }

    convenience init() {
        self.init(resurfacingService: MemoryResurfacingService(), calendar: .autoupdatingCurrent)
    }

    func refresh(memories: [MemoryRecord], now: Date = .now) {
        guard let result = resurfacingService.candidate(
            for: now,
            from: memories,
            calendar: calendar
        ) else {
            presentation = nil
            return
        }

        presentation = makePresentation(from: result, now: now)
    }

    func present(memory: MemoryRecord, now: Date = .now) {
        presentation = makePresentation(
            from: MemoryResurfacingResult(memory: memory, reason: .pastRandom),
            now: now
        )
    }

    private func makePresentation(
        from result: MemoryResurfacingResult,
        now: Date
    ) -> RevisitPresentation {
        let capturedAt = result.memory.memoryDate
        let today = calendar.startOfDay(for: now)
        let capturedDay = calendar.startOfDay(for: capturedAt)
        let daysAgo = max(0, calendar.dateComponents([.day], from: capturedDay, to: today).day ?? 0)

        return RevisitPresentation(
            memoryID: result.memory.id,
            memory: result.memory,
            reason: result.reason,
            capturedAt: capturedAt,
            daysAgo: daysAgo,
            eyebrowText: eyebrowText(for: result.reason),
            relativeDateText: relativeDateText(
                for: result.reason,
                capturedAt: capturedDay,
                today: today,
                daysAgo: daysAgo
            )
        )
    }

    private func eyebrowText(for reason: MemoryResurfacingReason) -> String {
        switch reason {
        case .anniversary: "ON THIS DAY"
        case .forgotten: "A MEMORY RETURNED"
        case .pastRandom: "FROM THEN"
        }
    }

    private func relativeDateText(
        for reason: MemoryResurfacingReason,
        capturedAt: Date,
        today: Date,
        daysAgo: Int
    ) -> String {
        if reason == .anniversary {
            let years = max(0, calendar.dateComponents([.year], from: capturedAt, to: today).year ?? 0)
            if years == 1 { return "1 year ago" }
            if years > 1 { return "\(years) years ago" }
        }
        if daysAgo == 0 { return "Today" }
        if daysAgo == 1 { return "1 day ago" }
        if daysAgo >= 365 {
            let years = max(1, calendar.dateComponents([.year], from: capturedAt, to: today).year ?? 1)
            return years == 1 ? "1 year ago" : "\(years) years ago"
        }
        if daysAgo >= 60 {
            let months = max(2, calendar.dateComponents([.month], from: capturedAt, to: today).month ?? 2)
            return "\(months) months ago"
        }
        return "\(daysAgo) days ago"
    }
}
