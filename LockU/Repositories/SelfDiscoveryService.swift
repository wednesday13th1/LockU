import Foundation

nonisolated struct SelfDiscoveryMoment: Identifiable, Equatable, Sendable {
    let memories: [MemoryRecord]
    let prompt: String
    let periodIdentifier: String

    var id: String {
        periodIdentifier + memories.map { $0.id.uuidString }.joined(separator: "-")
    }
}

/// A metadata-only rediscovery rule. It deliberately does not infer personality,
/// sentiment, themes, or scores from photos, emoji, or notes.
nonisolated struct SelfDiscoveryService {
    static let minimumMemoryCount = 12
    static let preferredMemoryCount = 3
    static let minimumAgeDays = 7
    static let revisitCooldownDays = 7

    func moment(
        for date: Date,
        memories: [MemoryRecord],
        calendar: Calendar = .autoupdatingCurrent
    ) -> SelfDiscoveryMoment? {
        guard memories.count >= Self.minimumMemoryCount else { return nil }
        let today = calendar.startOfDay(for: date)
        let period = periodKey(for: today, calendar: calendar)

        // The entry appears only during one stable two-day window in each week.
        guard visibleDayWindow(for: today, calendar: calendar) else { return nil }
        guard let oldestAllowed = calendar.date(byAdding: .day, value: -Self.minimumAgeDays, to: today),
              let cooldownStart = calendar.date(byAdding: .day, value: -Self.revisitCooldownDays, to: today) else { return nil }

        let eligible = memories.filter { memory in
            let day = calendar.startOfDay(for: memory.memoryDate)
            guard day <= oldestAllowed else { return false }
            if let revisited = memory.lastRevisitedAt,
               revisited >= cooldownStart,
               revisited < today { return false }
            return true
        }
        guard eligible.count >= Self.preferredMemoryCount else { return nil }

        let daily = eligible.filter { $0.origin == .dailyCapture }
        let nonSeed = eligible.filter { $0.origin != .seedImport }
        let preferred = daily.count >= Self.preferredMemoryCount
            ? daily
            : (nonSeed.count >= Self.preferredMemoryCount ? nonSeed : eligible)
        let seed = stableHash(period)
        let ordered = preferred.sorted {
            stableHash($0.id.uuidString, seed: seed) < stableHash($1.id.uuidString, seed: seed)
        }
        let selected = spreadAcrossTime(ordered, count: Self.preferredMemoryCount, calendar: calendar)
        guard selected.count == Self.preferredMemoryCount else { return nil }

        return SelfDiscoveryMoment(
            memories: selected,
            prompt: prompts[Int(seed % UInt64(prompts.count))],
            periodIdentifier: period
        )
    }

    private let prompts = [
        "こういう瞬間、けっこう好きだった？",
        "今見ると、何が気になる？",
        "この頃の自分、どんなふうに見える？",
        "こんな日も、自分の時間だった。"
    ]

    private func visibleDayWindow(for date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        let start = 2 + (week % 5)
        return weekday == start || weekday == min(start + 1, 7)
    }

    private func periodKey(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(c.yearForWeekOfYear ?? 0)-W\(c.weekOfYear ?? 0)"
    }

    private func spreadAcrossTime(_ ordered: [MemoryRecord], count: Int, calendar: Calendar) -> [MemoryRecord] {
        var result: [MemoryRecord] = []
        for memory in ordered {
            let day = calendar.startOfDay(for: memory.memoryDate)
            let isDistinct = result.allSatisfy {
                abs(calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.memoryDate), to: day).day ?? 0) >= 3
            }
            if isDistinct { result.append(memory) }
            if result.count == count { break }
        }
        if result.count < count {
            for memory in ordered where !result.contains(where: { $0.id == memory.id }) {
                result.append(memory)
                if result.count == count { break }
            }
        }
        return result
    }

    private func stableHash(_ text: String, seed: UInt64 = 14_695_981_039_346_656_037) -> UInt64 {
        text.utf8.reduce(seed) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }
}
