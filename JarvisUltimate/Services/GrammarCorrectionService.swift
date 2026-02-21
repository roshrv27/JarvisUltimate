import AppKit
import NaturalLanguage

final class GrammarCorrectionService {

    func correct(text: String, language: String) -> String {
        var result = text
        result = fixSpelling(result, language: language)
        result = fixGrammar(result, language: language)
        result = fixPunctuation(result)
        return result
    }

    private func fixSpelling(_ text: String, language: String) -> String {
        let checker = NSSpellChecker.shared
        let tag = NSSpellChecker.uniqueSpellDocumentTag()
        var result = text
        var searchRange = NSRange(location: 0, length: (result as NSString).length)

        while searchRange.location < (result as NSString).length {
            let misspelled = checker.checkSpelling(
                of: result, startingAt: searchRange.location,
                language: language, wrap: false,
                inSpellDocumentWithTag: tag, wordCount: nil
            )
            guard misspelled.length > 0 else { break }

            if let correction = checker.correction(
                forWordRange: misspelled, in: result,
                language: language, inSpellDocumentWithTag: tag
            ) {
                result = (result as NSString).replacingCharacters(in: misspelled, with: correction)
            }
            searchRange.location = misspelled.location + max(misspelled.length, 1)
            searchRange.length = (result as NSString).length - searchRange.location
        }

        checker.closeSpellDocument(withTag: tag)
        return result
    }

    private func fixGrammar(_ text: String, language: String) -> String {
        let checker = NSSpellChecker.shared
        let tag = NSSpellChecker.uniqueSpellDocumentTag()
        var result = text
        var details: NSArray?

        let grammarRange = checker.checkGrammar(
            of: result, startingAt: 0, language: language,
            wrap: false, inSpellDocumentWithTag: tag, details: &details
        )

        if grammarRange.length > 0, let detailsArray = details as? [[String: Any]] {
            // Apply corrections in reverse order to preserve ranges
            for detail in detailsArray.reversed() {
                if let corrections = detail[NSGrammarCorrections] as? [String],
                   let range = detail[NSGrammarRange] as? NSValue {
                    let nsRange = range.rangeValue
                    if let first = corrections.first {
                        result = (result as NSString).replacingCharacters(in: nsRange, with: first)
                    }
                }
            }
        }

        checker.closeSpellDocument(withTag: tag)
        return result
    }

    private func fixPunctuation(_ text: String) -> String {
        var str = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !str.isEmpty else { return str }

        // 1. Capitalize first letter of whole text
        str = str.prefix(1).uppercased() + str.dropFirst()

        // 2. Fix capitalization after . ! ?
        // We look for a sentence terminator followed by whitespace and a lowercase letter
        let pattern = "([.!?]\\s+)([a-z])"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsRange = NSRange(str.startIndex..., in: str)
            let matches = regex.matches(in: str, options: [], range: nsRange)
            
            // Appy changes in reverse to keep indices valid
            for match in matches.reversed() {
                if let lowercaseRange = Range(match.range(at: 2), in: str) {
                    let upper = str[lowercaseRange].uppercased()
                    str.replaceSubrange(lowercaseRange, with: upper)
                }
            }
        }

        // 3. Add period if text doesn't end with punctuation
        if let last = str.last, !".!?\"')".contains(last) {
            str += "."
        }

        return str
    }
}
