import Foundation

struct DailyLikeLog: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let imageFileName: String
    let note: String
}
