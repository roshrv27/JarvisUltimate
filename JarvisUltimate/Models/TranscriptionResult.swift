import Foundation

struct JarvisTranscriptionResult: Identifiable, Codable {
    let id: UUID
    let rawText: String
    let correctedText: String
    let detectedLanguage: String
    let confidence: Double
    let durationSeconds: Double
    let transcriptionTimeMs: Int
    let timestamp: Date
    let words: [String]
    let wasCloudFallback: Bool
}
