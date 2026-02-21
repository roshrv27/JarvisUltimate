import Foundation

final class CorrectionMemoryService {
    private var entries: [CorrectionEntry] = []
    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("JarvisUltimate")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("corrections.json")
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([CorrectionEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Post-processing: auto-replace known mistakes

    func applyCorrections(to text: String) -> String {
        var result = text
        for entry in entries where entry.alwaysReplace {
            // Case-insensitive whole-word replacement
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: entry.wrongText))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result, range: NSRange(result.startIndex..., in: result),
                    withTemplate: entry.correctText
                )
            }
        }
        return result
    }

    // MARK: - Pre-processing: generate prompt bias for Whisper

    func generatePromptBias() -> String? {
        let top = entries
            .sorted { $0.occurrenceCount > $1.occurrenceCount }
            .prefix(50)
            .map(\.correctText)
        guard !top.isEmpty else { return nil }
        return "Vocabulary: " + top.joined(separator: ", ")
    }

    // MARK: - CRUD

    func addCorrection(wrong: String, correct: String, language: String, alwaysReplace: Bool = true) {
        let key = wrong.lowercased()
        if let idx = entries.firstIndex(where: { $0.wrongText.lowercased() == key && $0.language == language }) {
            entries[idx].occurrenceCount += 1
            entries[idx].correctText = correct
            entries[idx].alwaysReplace = alwaysReplace
            entries[idx].lastUsedAt = Date()
        } else {
            entries.append(CorrectionEntry(
                id: UUID(), wrongText: wrong, correctText: correct,
                language: language, occurrenceCount: 1, alwaysReplace: alwaysReplace,
                createdAt: Date(), lastUsedAt: Date()
            ))
        }
        save()
    }

    func removeCorrection(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func allCorrections() -> [CorrectionEntry] { entries }

    func exportJSON() -> Data? { try? JSONEncoder().encode(entries) }

    func importJSON(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode([CorrectionEntry].self, from: data) else { return }
        entries = decoded
        save()
    }
}
