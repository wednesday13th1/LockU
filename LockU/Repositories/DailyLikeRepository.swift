import Combine
import Foundation
import UIKit

@MainActor
final class DailyLikeRepository: ObservableObject {
    @Published private(set) var logs: [DailyLikeLog] = []
    private let directory: URL
    private let store: SafeJSONStore<DailyLikeLog>
    private let calendar: Calendar

    init(paths: LockUPaths, calendar: Calendar = .autoupdatingCurrent) {
        directory = paths.dailyLikes
        store = SafeJSONStore(directory: paths.dailyLikes, fileName: "daily-likes.json")
        self.calendar = calendar
    }

    func reload() throws {
        logs = try store.load { !$0.imageFileName.isEmpty && !$0.note.isEmpty }
            .sorted { $0.date > $1.date }
    }

    func log(for date: Date) -> DailyLikeLog? {
        logs.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func image(for log: DailyLikeLog) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(log.imageFileName).path)
    }

    func save(image: UIImage, note: String, date: Date) throws {
        guard log(for: date) == nil else { return }
        let trimmed = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !trimmed.isEmpty, let data = image.jpegData(compressionQuality: 0.88) else {
            throw LockUStorageError.invalidImage
        }
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        logs.insert(DailyLikeLog(id: id, date: date, imageFileName: fileName, note: trimmed), at: 0)
        do { try store.save(logs) }
        catch {
            logs.removeAll { $0.id == id }
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
            throw error
        }
    }
}
