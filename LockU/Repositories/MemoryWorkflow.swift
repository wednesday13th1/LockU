import Foundation
import UIKit

struct DailyMemoryPolicy {
    let calendar: Calendar
    init(calendar: Calendar = .current) { self.calendar = calendar }
    func canCreateMemory(on date: Date, existing: [MemoryRecord]) -> Bool {
        !existing.contains { calendar.isDate($0.createdAt, inSameDayAs: date) }
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
}

struct CaptureMemoryResult { let memory: MemoryRecord }

enum MemorySaveState { case idle, validating, processingImage, writingImage, writingMetadata, committing, completed, failed }

@MainActor
final class CaptureMemoryWorkflow {
    private unowned let repository: MemoryRepository
    private let policy: DailyMemoryPolicy
    private(set) var state: MemorySaveState = .idle
    init(repository: MemoryRepository, policy: DailyMemoryPolicy = DailyMemoryPolicy()) { self.repository = repository; self.policy = policy }
    func execute(_ request: CaptureMemoryRequest) throws -> CaptureMemoryResult {
        state = .validating
        do {
            try policy.validateCreation(on: request.createdAt, existing: repository.memories)
            state = .writingImage
            let record = try repository.createImageRecord(request, enforceDailyLimit: false)
            state = .completed
            return CaptureMemoryResult(memory: record)
        } catch { state = .failed; throw error }
    }
}
