import Foundation

enum LockerTimePeriod: String, Codable, CaseIterable, Sendable {
    case morning
    case day
    case afterSchool
    case night
}

struct LockerTimePeriodService {
    let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func period(for date: Date) -> LockerTimePeriod {
        switch calendar.component(.hour, from: date) {
        case 6..<12: .morning
        case 12..<17: .day
        case 17..<21: .afterSchool
        default: .night
        }
    }
}

struct LockerMemoryVariationPlan: Equatable, Sendable {
    let period: LockerTimePeriod
    let primaryMemoryID: UUID?
    let secondaryMemoryID: UUID?
    let resurfacedMemoryID: UUID?
    let resurfacingReason: MemoryResurfacingReason?
    let dayIdentifier: String

    var emphasizedMemoryIDs: [UUID] {
        [primaryMemoryID, secondaryMemoryID].compactMap { $0 }
    }
}

struct LockerMemoryVariationService {
    private let calendar: Calendar
    private let periodService: LockerTimePeriodService
    private let resurfacingService: MemoryResurfacingService

    init(calendar: Calendar, resurfacingService: MemoryResurfacingService) {
        self.calendar = calendar
        periodService = LockerTimePeriodService(calendar: calendar)
        self.resurfacingService = resurfacingService
    }

    init() {
        self.init(calendar: .autoupdatingCurrent, resurfacingService: MemoryResurfacingService())
    }

    func plan(
        for date: Date,
        memories: [MemoryRecord],
        featuredVideoMemoryID: UUID?,
        enabled: Bool
    ) -> LockerMemoryVariationPlan {
        let period = periodService.period(for: date)
        let identifier = dayIdentifier(for: date)
        guard enabled else {
            return emptyPlan(period: period, dayIdentifier: identifier)
        }

        let today = calendar.startOfDay(for: date)
        let eligible = memories
            .filter { memory in
                memory.id != featuredVideoMemoryID
                    && calendar.startOfDay(for: memory.memoryDate) <= today
            }
            .sorted(by: stableRecentOrder)

        switch period {
        case .morning:
            let recentBeforeToday = eligible.filter {
                calendar.startOfDay(for: $0.memoryDate) < today
            }
            return plan(
                period: period,
                selected: Array(recentBeforeToday.prefix(2)),
                dayIdentifier: identifier
            )

        case .day:
            return emptyPlan(period: period, dayIdentifier: identifier)

        case .afterSchool:
            let todayDaily = eligible.first {
                $0.origin == .dailyCapture && calendar.isDate($0.memoryDate, inSameDayAs: today)
            }
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
            let yesterdayMemory = yesterday.flatMap { day in
                eligible.first { calendar.isDate($0.memoryDate, inSameDayAs: day) }
            }

            var selected: [MemoryRecord] = []
            if let todayDaily { selected.append(todayDaily) }
            if let yesterdayMemory, !selected.contains(where: { $0.id == yesterdayMemory.id }) {
                selected.append(yesterdayMemory)
            }
            if selected.isEmpty, let recent = eligible.first(where: {
                calendar.startOfDay(for: $0.memoryDate) < today
            }) {
                selected.append(recent)
            }
            if selected.count < 2, let next = eligible.first(where: { candidate in
                calendar.startOfDay(for: candidate.memoryDate) < today
                    && !selected.contains(where: { $0.id == candidate.id })
            }) {
                selected.append(next)
            }
            return plan(period: period, selected: selected, dayIdentifier: identifier)

        case .night:
            guard let resurfaced = resurfacingService.candidate(
                for: date,
                from: eligible,
                calendar: calendar
            ) else {
                return emptyPlan(period: period, dayIdentifier: identifier)
            }
            return LockerMemoryVariationPlan(
                period: period,
                primaryMemoryID: resurfaced.memory.id,
                secondaryMemoryID: nil,
                resurfacedMemoryID: resurfaced.memory.id,
                resurfacingReason: resurfaced.reason,
                dayIdentifier: identifier
            )
        }
    }

    private func plan(
        period: LockerTimePeriod,
        selected: [MemoryRecord],
        dayIdentifier: String
    ) -> LockerMemoryVariationPlan {
        LockerMemoryVariationPlan(
            period: period,
            primaryMemoryID: selected.first?.id,
            secondaryMemoryID: selected.dropFirst().first?.id,
            resurfacedMemoryID: nil,
            resurfacingReason: nil,
            dayIdentifier: dayIdentifier
        )
    }

    private func emptyPlan(
        period: LockerTimePeriod,
        dayIdentifier: String
    ) -> LockerMemoryVariationPlan {
        LockerMemoryVariationPlan(
            period: period,
            primaryMemoryID: nil,
            secondaryMemoryID: nil,
            resurfacedMemoryID: nil,
            resurfacingReason: nil,
            dayIdentifier: dayIdentifier
        )
    }

    private func stableRecentOrder(_ lhs: MemoryRecord, _ rhs: MemoryRecord) -> Bool {
        if lhs.memoryDate != rhs.memoryDate { return lhs.memoryDate > rhs.memoryDate }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func dayIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
