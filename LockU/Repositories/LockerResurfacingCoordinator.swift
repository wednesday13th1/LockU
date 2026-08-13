import Combine
import Foundation

@MainActor
final class LockerResurfacingCoordinator: ObservableObject {
    @Published private(set) var candidateMemoryID: UUID?
    @Published private(set) var presentedMemoryID: UUID?
    @Published private(set) var candidateReflectionTrace: MemoryReflectionTraceMetadata?

    private let service: MemoryResurfacingService
    private let calendar: Calendar
    private let defaults: UserDefaults
    private let reflectionTraceService: MemoryReflectionTraceService
    private let dailyKey = "locku.locker-resurfacing.daily.v1"
    private let recentKey = "locku.locker-resurfacing.recent.v1"
    private let recentLimit = 8
    private var recordedMemoryIDForCurrentPresentation: UUID?

    init(
        service: MemoryResurfacingService = MemoryResurfacingService(),
        calendar: Calendar = .autoupdatingCurrent,
        defaults: UserDefaults = .standard,
        reflectionTraceService: MemoryReflectionTraceService? = nil
    ) {
        self.service = service
        self.calendar = calendar
        self.defaults = defaults
        self.reflectionTraceService = reflectionTraceService ?? MemoryReflectionTraceService(defaults: defaults)
    }

    func refresh(date: Date, memories: [MemoryRecord], growthStage: LockerGrowthStage) {
        reflectionTraceService.removeStaleRecords(validMemoryIDs: Set(memories.map(\.id)))
        guard growthStage.rawValue >= LockerGrowthStage.personal.rawValue else {
            candidateMemoryID = nil
            presentedMemoryID = nil
            candidateReflectionTrace = nil
            return
        }

        let key = dayIdentifier(for: date)
        if let stored = storedDailySelection(), stored.day == key,
           memories.contains(where: { $0.id == stored.memoryID && $0.memoryDate < date }) {
            candidateMemoryID = stored.memoryID
            candidateReflectionTrace = reflectionTraceService.metadata(for: stored.memoryID)
            return
        }

        let recent = Set(recentIDs())
        let candidate = service.lockerCandidate(
            for: date,
            from: memories,
            excluding: recent,
            calendar: calendar
        )
        candidateMemoryID = candidate?.id
        candidateReflectionTrace = candidate.flatMap { reflectionTraceService.metadata(for: $0.id) }
        if let candidate {
            defaults.set("\(key)|\(candidate.id.uuidString)", forKey: dailyKey)
        } else {
            defaults.removeObject(forKey: dailyKey)
        }
    }

    func presentCandidate(from repository: MemoryRepository, at date: Date) {
        guard let candidateMemoryID,
              repository.memories.contains(where: { $0.id == candidateMemoryID }) else {
            self.candidateMemoryID = nil
            return
        }
        presentedMemoryID = candidateMemoryID
        recordedMemoryIDForCurrentPresentation = nil
        remember(candidateMemoryID)
        try? repository.markMemoryAsRevisited(id: candidateMemoryID, at: date)
    }

    func close() {
        presentedMemoryID = nil
        recordedMemoryIDForCurrentPresentation = nil
    }

    func recordPresentedReflection(at date: Date) {
        guard let memoryID = presentedMemoryID,
              recordedMemoryIDForCurrentPresentation != memoryID else { return }
        candidateReflectionTrace = reflectionTraceService.recordReflection(memoryID: memoryID, at: date)
        recordedMemoryIDForCurrentPresentation = memoryID
    }

    private func remember(_ id: UUID) {
        var recent = recentIDs().filter { $0 != id }
        recent.insert(id, at: 0)
        defaults.set(recent.prefix(recentLimit).map(\.uuidString), forKey: recentKey)
    }

    private func recentIDs() -> [UUID] {
        (defaults.stringArray(forKey: recentKey) ?? []).compactMap(UUID.init(uuidString:))
    }

    private func storedDailySelection() -> (day: String, memoryID: UUID)? {
        guard let value = defaults.string(forKey: dailyKey),
              let separator = value.lastIndex(of: "|"),
              let id = UUID(uuidString: String(value[value.index(after: separator)...])) else { return nil }
        return (String(value[..<separator]), id)
    }

    private func dayIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
