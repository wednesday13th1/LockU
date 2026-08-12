import Foundation
import UIKit

@MainActor
struct CompleteRevisitWorkflow {
    let memoryRepository: MemoryRepository
    let reflectionRepository: MemoryReflectionRepository

    func execute(memoryID: UUID, reflectionText: String, completedAt: Date = .now) throws {
        guard memoryRepository.memories.contains(where: { $0.id == memoryID }) else {
            throw LockUStorageError.recordNotFound
        }

        let normalized = try MemoryReflectionPolicy.normalized(reflectionText)
        var createdReflectionID: UUID?
        if let normalized {
            createdReflectionID = try reflectionRepository.add(
                memoryID: memoryID,
                text: normalized,
                createdAt: completedAt
            )?.id
        }

        do {
            try memoryRepository.markMemoryAsRevisited(id: memoryID, at: completedAt)
        } catch {
            if let createdReflectionID {
                do {
                    try reflectionRepository.delete(id: createdReflectionID)
                } catch let rollbackError {
                    LockULog.error(.transaction, "Revisit completion rollback failed: \(rollbackError.localizedDescription)")
                }
            }
            throw error
        }
    }
}

nonisolated struct DailyMemoryPolicy {
    let calendar: Calendar
    init(calendar: Calendar = .current) { self.calendar = calendar }
    func canCreateMemory(on date: Date, existing: [MemoryRecord]) -> Bool {
        !existing.contains { $0.origin != .seedImport && calendar.isDate($0.createdAt, inSameDayAs: date) }
    }
    func validateCreation(on date: Date, existing: [MemoryRecord]) throws {
        guard canCreateMemory(on: date, existing: existing) else { throw DailyMemoryPolicyError.alreadyCapturedToday }
    }
}

enum DailyMemoryPolicyError: LocalizedError {
    case alreadyCapturedToday
    var errorDescription: String? { "今日の思い出はすでに保存されています。明日また撮影できます。" }
}

struct CaptureMemoryRequest {
    let image: UIImage
    let createdAt: Date
    let filterID: String?
    let weather: WeatherSnapshot?
    let captureMode: CaptureMode
    let imageStyle: MemoryImageStyle
    let dailyFilm: DailyFilm?
    let memoryNote: String?
    let origin: MemoryOrigin
    let importedAt: Date?

    func withMemoryNote(_ note: String?) -> Self {
        Self(image: image, createdAt: createdAt, filterID: filterID, weather: weather, captureMode: captureMode, imageStyle: imageStyle, dailyFilm: dailyFilm, memoryNote: note, origin: origin, importedAt: importedAt)
    }
}

struct MemoryNotePolicy {
    static let maximumLength = 30

    func normalize(_ note: String?) throws -> String? {
        guard let note else { return nil }
        let normalized = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        guard normalized.count <= Self.maximumLength else { throw MemoryNotePolicyError.tooLong }
        return normalized
    }
}

enum MemoryNotePolicyError: LocalizedError {
    case tooLong
    var errorDescription: String? { "一言は30文字以内で入力してください。" }
}

struct CaptureMemoryResult { let memory: MemoryRecord }

enum MemorySaveState { case idle, validating, processingImage, writingImage, writingMetadata, committing, completed, failed }

@MainActor
final class CaptureMemoryWorkflow {
    private unowned let repository: MemoryRepository
    private let policy: DailyMemoryPolicy
    private(set) var state: MemorySaveState = .idle
    init(repository: MemoryRepository, policy: DailyMemoryPolicy) {
        self.repository = repository
        self.policy = policy
    }
    convenience init(repository: MemoryRepository) {
        self.init(repository: repository, policy: DailyMemoryPolicy())
    }
    func execute(_ request: CaptureMemoryRequest) throws -> CaptureMemoryResult {
        state = .validating
        do {
            try policy.validateCreation(on: request.createdAt, existing: repository.memories)
            let validatedRequest = request.withMemoryNote(try MemoryNotePolicy().normalize(request.memoryNote))
            state = .writingImage
            let record = try repository.createImageRecord(validatedRequest, enforceDailyLimit: false)
            state = .completed
            return CaptureMemoryResult(memory: record)
        } catch { state = .failed; throw error }
    }
}
