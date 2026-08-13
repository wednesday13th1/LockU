import Foundation

enum ReflectionTraceStyle: String, Codable, CaseIterable, Sendable {
    case dateTape
    case pencilMark
    case tinyStar
    case cornerFold
    case softCheck
}

struct MemoryReflectionTraceMetadata: Codable, Equatable, Sendable {
    let memoryID: UUID
    let firstReflectedAt: Date
    var lastReflectedAt: Date
    var reflectionCount: Int
    let traceStyle: ReflectionTraceStyle
}

@MainActor
final class MemoryReflectionTraceService {
    private let defaults: UserDefaults
    private let storageKey = "locku.reflection-traces.v1"
    private var records: [UUID: MemoryReflectionTraceMetadata]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([MemoryReflectionTraceMetadata].self, from: data) {
            records = Dictionary(uniqueKeysWithValues: decoded.map { ($0.memoryID, $0) })
        } else {
            records = [:]
        }
    }

    @discardableResult
    func recordReflection(memoryID: UUID, at date: Date) -> MemoryReflectionTraceMetadata {
        if var existing = records[memoryID] {
            existing.lastReflectedAt = date
            existing.reflectionCount += 1
            records[memoryID] = existing
            persist()
            return existing
        }

        let metadata = MemoryReflectionTraceMetadata(
            memoryID: memoryID,
            firstReflectedAt: date,
            lastReflectedAt: date,
            reflectionCount: 1,
            traceStyle: traceStyle(memoryID: memoryID, firstReflectedAt: date)
        )
        records[memoryID] = metadata
        persist()
        return metadata
    }

    func metadata(for memoryID: UUID) -> MemoryReflectionTraceMetadata? {
        records[memoryID]
    }

    func removeStaleRecords(validMemoryIDs: Set<UUID>) {
        let filtered = records.filter { validMemoryIDs.contains($0.key) }
        guard filtered.count != records.count else { return }
        records = filtered
        persist()
    }

    private func traceStyle(memoryID: UUID, firstReflectedAt: Date) -> ReflectionTraceStyle {
        let day = Calendar.autoupdatingCurrent.startOfDay(for: firstReflectedAt)
        let seedValue = memoryID.uuidString + "|" + String(Int(day.timeIntervalSince1970))
        let seed = seedValue.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return ReflectionTraceStyle.allCases[Int(seed % UInt64(ReflectionTraceStyle.allCases.count))]
    }

    private func persist() {
        let ordered = records.values.sorted { $0.memoryID.uuidString < $1.memoryID.uuidString }
        guard let data = try? JSONEncoder().encode(ordered) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
