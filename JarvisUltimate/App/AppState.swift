import SwiftUI
import Observation

enum RecordingState: Equatable {
    case idle
    case downloadingModel(progress: Double)       // first launch model download
    case recording(startTime: Date)
    case transcribing
    case inserting
    case showingConfirmation(text: String)
    case showingCorrection
    case error(message: String)                   // transcription/permission failure
}

@MainActor
@Observable
final class AppState {
    var recordingState: RecordingState = .idle
    var currentAmplitudes: [Float] = []           // capped at 120 entries (ring buffer)
    var recordingDuration: TimeInterval = 0
    var lastResult: JarvisTranscriptionResult?
    var recentResults: [JarvisTranscriptionResult] = [] // in-memory only, lost on restart
    var isSettingsOpen: Bool = false
    var modelReady: Bool = false                  // false until WhisperKit model is loaded

    func appendAmplitude(_ value: Float) {
        currentAmplitudes.append(value)
        if currentAmplitudes.count > 120 {
            currentAmplitudes.removeFirst(currentAmplitudes.count - 120)
        }
    }

    func clearAmplitudes() {
        currentAmplitudes.removeAll()
    }
}
