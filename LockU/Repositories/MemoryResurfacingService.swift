import Foundation

nonisolated enum MemoryResurfacingReason: String, Codable, Equatable, Sendable {
    case anniversary
    case forgotten
    case pastRandom
}

nonisolated struct MemoryResurfacingResult: Equatable, Sendable {
    let memory: MemoryRecord
    let reason: MemoryResurfacingReason
}

nonisolated struct MemoryResurfacingService {
    static let minimumMemoryCount = 7
    static let fullRevisitMemoryCount = 14
    static let forgottenThresholdDays = 30
    static let randomPastMinimumAgeDays = 14
    static let revisitCooldownDays = 7

    func candidate(
        for date: Date,
        from memories: [MemoryRecord],
        calendar: Calendar = .autoupdatingCurrent
    ) -> MemoryResurfacingResult? {
        let today = calendar.startOfDay(for: date)
        let past = memories.filter { memory in
            let memoryDay = calendar.startOfDay(for: memory.memoryDate)
            return memoryDay < today && !calendar.isDate(memoryDay, inSameDayAs: today)
        }

        if let anniversary = anniversaryCandidate(for: today, from: past, calendar: calendar) {
            return MemoryResurfacingResult(memory: anniversary, reason: .anniversary)
        }

        guard memories.count >= Self.minimumMemoryCount else { return nil }

        if let forgotten = forgottenCandidate(for: today, from: past, calendar: calendar) {
            return MemoryResurfacingResult(memory: forgotten, reason: .forgotten)
        }

        guard memories.count >= Self.fullRevisitMemoryCount,
              let randomPast = stablePastCandidate(for: today, from: past, calendar: calendar) else {
            return nil
        }
        return MemoryResurfacingResult(memory: randomPast, reason: .pastRandom)
    }

    private func anniversaryCandidate(for today: Date, from memories: [MemoryRecord], calendar: Calendar) -> MemoryRecord? {
        let todayComponents = calendar.dateComponents([.month, .day], from: today)
        return memories
            .filter {
                let components = calendar.dateComponents([.month, .day], from: $0.memoryDate)
                return components.month == todayComponents.month && components.day == todayComponents.day
            }
            .max { $0.memoryDate < $1.memoryDate }
    }

    private func forgottenCandidate(for today: Date, from memories: [MemoryRecord], calendar: Calendar) -> MemoryRecord? {
        guard let threshold = calendar.date(byAdding: .day, value: -Self.forgottenThresholdDays, to: today) else { return nil }
        return memories
            .filter { calendar.startOfDay(for: $0.memoryDate) <= threshold && isOutsideRevisitCooldown($0, today: today, calendar: calendar) }
            .sorted { lhs, rhs in
                switch (lhs.lastRevisitedAt, rhs.lastRevisitedAt) {
                case (nil, .some): return true
                case (.some, nil): return false
                case let (.some(left), .some(right)) where left != right: return left < right
                default: return lhs.memoryDate > rhs.memoryDate
                }
            }
            .first
    }

    private func stablePastCandidate(for today: Date, from memories: [MemoryRecord], calendar: Calendar) -> MemoryRecord? {
        guard let threshold = calendar.date(byAdding: .day, value: -Self.randomPastMinimumAgeDays, to: today) else { return nil }
        let eligible = memories.filter {
            calendar.startOfDay(for: $0.memoryDate) <= threshold && isOutsideRevisitCooldown($0, today: today, calendar: calendar)
        }
        guard !eligible.isEmpty else { return nil }
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        let daySeed = UInt64((dayComponents.year ?? 0) * 10_000 + (dayComponents.month ?? 0) * 100 + (dayComponents.day ?? 0))
        return eligible.min { stableScore(for: $0.id, daySeed: daySeed) < stableScore(for: $1.id, daySeed: daySeed) }
    }

    private func stableScore(for id: UUID, daySeed: UInt64) -> UInt64 {
        id.uuidString.utf8.reduce(14_695_981_039_346_656_037 ^ daySeed) { value, byte in
            (value ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    private func isOutsideRevisitCooldown(_ memory: MemoryRecord, today: Date, calendar: Calendar) -> Bool {
        guard let lastRevisitedAt = memory.lastRevisitedAt,
              let cooldownStart = calendar.date(byAdding: .day, value: -Self.revisitCooldownDays, to: today) else {
            return true
        }
        return lastRevisitedAt < cooldownStart
    }
}
