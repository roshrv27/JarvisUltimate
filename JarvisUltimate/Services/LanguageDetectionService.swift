import NaturalLanguage

final class LanguageDetectionService {
    func detect(text: String, whisperHint: String?) -> (code: String, displayName: String) {
        let recognizer = NLLanguageRecognizer()

        if let hint = whisperHint {
            let nlLang = NLLanguage(rawValue: hint)
            recognizer.languageHints = [nlLang: 0.8]
        }

        recognizer.processString(text)
        let dominant = recognizer.dominantLanguage ?? .english
        let code = dominant.rawValue
        let displayName = Locale.current.localizedString(forLanguageCode: code)
            ?? code.uppercased()
        return (code, displayName)
    }
}
