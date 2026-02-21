import SwiftUI
import Observation

@Observable
final class AppSettings {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    var selectedModel: String {
        didSet { defaults.set(selectedModel, forKey: "selectedModel") }
    }

    var maxRecordingSeconds: Int {
        didSet { defaults.set(maxRecordingSeconds, forKey: "maxRecordingSeconds") }
    }


    var recordHotkeyCode: UInt16 {
        didSet { defaults.set(Int(recordHotkeyCode), forKey: "recordHotkeyCode") }
    }

    var recordHotkeyModifiers: UInt {
        didSet { defaults.set(recordHotkeyModifiers, forKey: "recordHotkeyModifiers") }
    }

    var correctionHotkeyCode: UInt16 {
        didSet { defaults.set(Int(correctionHotkeyCode), forKey: "correctionHotkeyCode") }
    }

    var correctionHotkeyModifiers: UInt {
        didSet { defaults.set(correctionHotkeyModifiers, forKey: "correctionHotkeyModifiers") }
    }

    init() {
        self.selectedModel = defaults.string(forKey: "selectedModel") ?? "openai_whisper-large-v3-v20240930_turbo_632MB"
        self.maxRecordingSeconds = defaults.object(forKey: "maxRecordingSeconds") as? Int ?? 120
        
        let recordKey = defaults.integer(forKey: "recordHotkeyCode")
        self.recordHotkeyCode = UInt16(recordKey == 0 ? 49 : recordKey)
        self.recordHotkeyModifiers = defaults.object(forKey: "recordHotkeyModifiers") as? UInt ?? 0x120000
        
        let corrKey = defaults.integer(forKey: "correctionHotkeyCode")
        self.correctionHotkeyCode = UInt16(corrKey == 0 ? 8 : corrKey)
        self.correctionHotkeyModifiers = defaults.object(forKey: "correctionHotkeyModifiers") as? UInt ?? 0x120000
    }

    static let modelPresets: [(id: String, name: String, model: String, description: String, size: String)] = [
        ("max",       "Maximum Accuracy", "openai_whisper-large-v3-v20240930",              "Full large-v3, highest accuracy",  "~3 GB"),
        ("balanced",  "Balanced",         "openai_whisper-large-v3-v20240930_turbo_632MB",  "Best accuracy-to-speed ratio",     "632 MB"),
        ("fast",      "Fast",             "distil-whisper_distil-large-v3_turbo_600MB",     "6x faster, within 1% WER",         "600 MB"),
        ("light",     "Lightweight",      "openai_whisper-small_216MB",                      "Low memory, decent accuracy",      "216 MB"),
    ]

    static let durationPresets: [(name: String, maxSec: Int, silenceSec: Double)] = [
        ("Quick dictation", 30, 2.0),
        ("Standard",       120, 3.0),
        ("Extended",       300, 5.0),
        ("Unlimited",        0, 5.0),
    ]

    static func hotkeyDisplay(code: UInt16, modifiers: UInt) -> String {
        var result = ""
        let mods = NSEvent.ModifierFlags(rawValue: modifiers)
        if mods.contains(.control) { result += "⌃ " }
        if mods.contains(.option) { result += "⌥ " }
        if mods.contains(.shift) { result += "⇧ " }
        if mods.contains(.command) { result += "⌘ " }
        
        let keyMap: [UInt16: String] = [
            49: "Space", 36: "Return", 53: "Esc", 123: "←", 124: "→", 125: "↓", 126: "↑",
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B",
            12: "Q", 13: "W", 14: "E", 15: "R", 17: "T", 16: "Y", 32: "U", 34: "I", 31: "O", 35: "P"
        ]
        
        if let name = keyMap[code] {
            result += name
        } else {
            result += "Key \(code)"
        }
        return result
    }
}
