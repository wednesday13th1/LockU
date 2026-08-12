import Combine
import Foundation

struct RevisitPresentation: Identifiable, Equatable, Sendable {
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

    init(
        resurfacingService: MemoryResurfacingService = MemoryResurfacingService(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.resurfacingService = resurfacingService
        self.calendar = calendar
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
        case .forgotten: "YOU FORGOT THIS ONE."
        case .pastRandom: "FROM A WHILE AGO"
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
        return "\(daysAgo) days ago"
    }
}
