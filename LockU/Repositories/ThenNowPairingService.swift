import Foundation

nonisolated struct ThenNowMemoryPair: Identifiable, Equatable, Sendable {
    let thenMemory: MemoryRecord
    let nowMemory: MemoryRecord
    let dayGap: Int
    var id: String { "\(thenMemory.id.uuidString)-\(nowMemory.id.uuidString)" }
}

/// Metadata-only, explainable pairing. It never inspects pixels, emoji, or note meaning.
nonisolated struct ThenNowPairingService {
    static let minimumGapDays = 7
    static let nowWindowDays = 7
    static let thenCooldownDays = 4
    private let idealGaps = [14, 30, 60, 90, 180, 365]

    func pair(for date: Date, memories: [MemoryRecord], calendar: Calendar = .autoupdatingCurrent) -> ThenNowMemoryPair? {
        let today = calendar.startOfDay(for: date)
        let nonFuture = memories.filter { calendar.startOfDay(for: $0.memoryDate) <= today }
        guard let now = selectNow(today: today, memories: nonFuture, calendar: calendar) else { return nil }
        let nowDay = calendar.startOfDay(for: now.memoryDate)
        guard let oldestAllowed = calendar.date(byAdding: .day, value: -Self.minimumGapDays, to: nowDay) else { return nil }

        let eligible = nonFuture.filter { memory in
            let day = calendar.startOfDay(for: memory.memoryDate)
            guard memory.id != now.id, day <= oldestAllowed, !calendar.isDate(day, inSameDayAs: nowDay) else { return false }
            if let revisited = memory.lastRevisitedAt,
               let cooldownStart = calendar.date(byAdding: .day, value: -Self.thenCooldownDays, to: today),
               revisited >= cooldownStart,
               revisited < today { return false }
            return true
        }
        guard !eligible.isEmpty else { return nil }
        let preferred = preferredOrigins(in: eligible)
        let daySeed = stableDaySeed(today, calendar: calendar)
        let then = preferred.min { lhs, rhs in
            score(lhs, nowDay: nowDay, daySeed: daySeed, calendar: calendar)
                < score(rhs, nowDay: nowDay, daySeed: daySeed, calendar: calendar)
        }
        guard let then else { return nil }
        let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: then.memoryDate), to: nowDay).day ?? 0
        guard gap >= Self.minimumGapDays else { return nil }
        return ThenNowMemoryPair(thenMemory: then, nowMemory: now, dayGap: gap)
    }

    func pair(
        anchoredAt thenMemory: MemoryRecord,
        for date: Date,
        memories: [MemoryRecord],
        calendar: Calendar = .autoupdatingCurrent
    ) -> ThenNowMemoryPair? {
        let today = calendar.startOfDay(for: date)
        guard let now = selectNow(today: today, memories: memories, calendar: calendar),
              thenMemory.id != now.id else { return nil }
        let thenDay = calendar.startOfDay(for: thenMemory.memoryDate)
        let nowDay = calendar.startOfDay(for: now.memoryDate)
        let gap = calendar.dateComponents([.day], from: thenDay, to: nowDay).day ?? 0
        guard gap >= Self.minimumGapDays else { return nil }
        return ThenNowMemoryPair(thenMemory: thenMemory, nowMemory: now, dayGap: gap)
    }

    private func selectNow(today: Date, memories: [MemoryRecord], calendar: Calendar) -> MemoryRecord? {
        let todayMemories = memories.filter { calendar.isDate($0.memoryDate, inSameDayAs: today) }
        if !todayMemories.isEmpty {
            let dailyToday = todayMemories.filter { $0.origin == .dailyCapture }
            let nonSeedToday = todayMemories.filter { $0.origin != .seedImport }
            return (!dailyToday.isEmpty ? dailyToday : (!nonSeedToday.isEmpty ? nonSeedToday : todayMemories))
                .max { $0.memoryDate < $1.memoryDate }
        }
        let recent = memories.filter { memory in
            let age = calendar.dateComponents([.day], from: calendar.startOfDay(for: memory.memoryDate), to: today).day ?? Int.max
            return (0...Self.nowWindowDays).contains(age)
        }
        let daily = recent.filter { $0.origin == .dailyCapture }
        let pool = daily.isEmpty ? recent.filter { $0.origin != .seedImport } : daily
        let fallback = pool.isEmpty ? recent : pool
        return fallback.max { $0.memoryDate < $1.memoryDate }
    }

    private func preferredOrigins(in memories: [MemoryRecord]) -> [MemoryRecord] {
        let daily = memories.filter { $0.origin == .dailyCapture }
        if !daily.isEmpty { return daily }
        let nonSeed = memories.filter { $0.origin != .seedImport }
        return nonSeed.isEmpty ? memories : nonSeed
    }

    private func score(_ memory: MemoryRecord, nowDay: Date, daySeed: UInt64, calendar: Calendar) -> UInt64 {
        let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: memory.memoryDate), to: nowDay).day ?? 0
        let rotated = Array(idealGaps.dropFirst(Int(daySeed % UInt64(idealGaps.count)))) + Array(idealGaps.prefix(Int(daySeed % UInt64(idealGaps.count))))
        let distance = rotated.enumerated().map { index, ideal in abs(gap - ideal) * 10 + index }.min() ?? Int.max
        return UInt64(max(distance, 0)) * 1_000_000 + stableHash(memory.id, seed: daySeed) % 1_000_000
    }

    private func stableDaySeed(_ date: Date, calendar: Calendar) -> UInt64 {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return UInt64((c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0))
    }

    private func stableHash(_ id: UUID, seed: UInt64) -> UInt64 {
        id.uuidString.utf8.reduce(14_695_981_039_346_656_037 ^ seed) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }
}
