import Foundation

struct CorrectionEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var wrongText: String
    var correctText: String
    var language: String
    var occurrenceCount: Int
    var alwaysReplace: Bool
    let createdAt: Date
    var lastUsedAt: Date
}
