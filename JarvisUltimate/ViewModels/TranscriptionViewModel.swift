import SwiftUI
import Observation
import ApplicationServices

@MainActor
@Observable
final class TranscriptionViewModel {
    let appState: AppState
    private let settings = AppSettings.shared
    private let hotkey = HotkeyService()
    private let audio = AudioCaptureService()
    private let whisper = WhisperTranscriptionService()
    private let langDetect = LanguageDetectionService()
    private let grammar = GrammarCorrectionService()
    private let corrections = CorrectionMemoryService()
    private let textInserter = TextInsertionService()
    private var recordingTimer: Timer?
    private var lastAudioURL: URL?

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Bootstrap (call once at app launch)

    func bootstrap() async {
        NSLog("[TranscriptionViewModel] bootstrap started")
        corrections.load()
        
        // Request microphone permission at startup to avoid focus issues during recording
        let micGranted = await audio.requestMicrophonePermission()
        NSLog("[TranscriptionViewModel] Microphone permission: \(micGranted ? "granted" : "denied")")

        // Wire PTT callbacks (only Push-to-Talk is used now)
        hotkey.onPTTStart = { [weak self] in
            Task { @MainActor in self?.pttRecordingStart() }
        }
        
        hotkey.onPTTEnd = { [weak self] in
            Task { @MainActor in self?.pttRecordingEnd() }
        }
        
        hotkey.onCorrectionTrigger = { [weak self] in
            Task { @MainActor in self?.onCorrectionTrigger() }
        }
        
        // Wire audio callbacks
        audio.onAmplitude = { [weak self] amp in
            Task { @MainActor in self?.appState.appendAmplitude(amp) }
        }
        audio.onMaxDurationReached = { [weak self] in
            Task { @MainActor in self?.onMaxDuration() }
        }

        hotkey.start()
        
        setupModelObservation()

        whisper.onDownloadProgress = { [weak self] progress in
            Task { @MainActor in
                self?.appState.recordingState = .downloadingModel(progress: progress)
            }
        }

        // Initial Load Whisper model
        await loadCurrentModel()
    }

    private func setupModelObservation() {
        _ = withObservationTracking {
            settings.selectedModel
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                NSLog("[TranscriptionViewModel] Model selection changed to \(self.settings.selectedModel)")
                await self.loadCurrentModel()
                self.setupModelObservation() // keep observing
            }
        }
    }

    private func loadCurrentModel() async {
        appState.modelReady = false
        appState.recordingState = .downloadingModel(progress: 0)
        NSLog("[TranscriptionViewModel] loading model...")
        do {
            try await whisper.loadModel()
            appState.modelReady = true
            appState.recordingState = .idle
        } catch {
            appState.recordingState = .error(message: "Failed to load model: \(error.localizedDescription)")
            try? await Task.sleep(for: .seconds(3))
            appState.recordingState = .idle
        }
    }

    func resetAccessibility() {
        hotkey.resetAccessibilityDatabase()
    }

    func reregisterHotkeys() {
        hotkey.reregister()
    }
    
    func requestAccessibility() {
        // Force request accessibility permission prompt
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func refreshAccessibility() {
        hotkey.requestAccessibilityIfNeeded()
    }

    func updateRecordHotkey(code: UInt16, modifiers: UInt) {
        settings.recordHotkeyCode = code
        settings.recordHotkeyModifiers = modifiers
        hotkey.reregister()
    }

    func updateCorrectionHotkey(code: UInt16, modifiers: UInt) {
        settings.correctionHotkeyCode = code
        settings.correctionHotkeyModifiers = modifiers
        hotkey.reregister()
    }

    // MARK: - State Machine

    func toggleRecording() {
        NSLog("[TranscriptionViewModel] toggleRecording called. State: \(appState.recordingState)")
        switch appState.recordingState {
        case .idle:
            guard appState.modelReady else {
                appState.recordingState = .error(message: "Model still loading, please wait...")
                dismissErrorAfterDelay()
                return
            }
            startRecording()
        case .recording:
            stopAndTranscribe()
        default:
            break
        }
    }
    
    // Push-to-Talk methods
    private func pttRecordingStart() {
        guard case .idle = appState.recordingState, appState.modelReady else { return }
        startRecording()
    }
    
    private func pttRecordingEnd() {
        guard case .recording = appState.recordingState else { return }
        
        stopAndTranscribe()
    }

    private func startRecording() {
        appState.clearAmplitudes()
        appState.recordingDuration = 0
        appState.recordingState = .recording(startTime: Date())

        Task {
            // Request microphone permission if not already granted
            let granted = await audio.requestMicrophonePermissionIfNeeded()
            guard granted else {
                await MainActor.run {
                    self.appState.recordingState = .error(message: "Microphone permission denied. Please enable in System Settings > Privacy & Security > Microphone")
                    self.dismissErrorAfterDelay()
                }
                return
            }

            do {
                try await MainActor.run {
                    try self.audio.startRecording()
                }
            } catch {
                await MainActor.run {
                    self.appState.recordingState = .error(message: "Microphone error: \(error.localizedDescription)")
                    self.dismissErrorAfterDelay()
                }
                return
            }
        }

        // Duration timer (updates UI every 0.1s)
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, case .recording(let start) = self.appState.recordingState else { return }
                self.appState.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopAndTranscribe() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        let audioURL = audio.stopRecording()
        lastAudioURL = audioURL

        // Discard recordings shorter than 0.5s
        guard appState.recordingDuration >= 0.5, let audioURL else {
            cleanupTempFile()
            appState.recordingState = .idle
            return
        }

        appState.recordingState = .transcribing
        NSLog("[TranscriptionViewModel] Processing started...")

        Task {
            let totalStart = Date()
            let startTime = Date()

            do {
                // 1. Prompt bias from correction memory
                let promptBias = corrections.generatePromptBias()

                // 2. Local transcription
                var rawText: String
                var lang: String
                var confidence: Double
                var usedCloud = false

                let samples = audio.getRecordedSamples()

                do {
                    (rawText, lang, confidence) = try await whisper.transcribe(
                        audioURL: audioURL, audioSamples: samples, promptBias: promptBias
                    )
                } catch WhisperTranscriptionService.TranscriptionError.lowConfidence(let text, let language) {
                    // Just use local result even if low confidence
                    rawText = text; lang = language; confidence = 0.4
                } catch {
                    // No cloud fallback anymore - just fail
                    throw error
                }
                
                let whisperDone = Date()
                NSLog("[TranscriptionViewModel] Step 2 (Transcription) took \(String(format: "%.2f", whisperDone.timeIntervalSince(startTime)))s")

                // 3. Language detection
                let detectedLang = langDetect.detect(text: rawText, whisperHint: lang)

                // 4. Grammar correction
                let grammarStart = Date()
                let grammarFixed = grammar.correct(text: rawText, language: detectedLang.code)
                NSLog("[TranscriptionViewModel] Step 4 (Grammar) took \(String(format: "%.2f", Date().timeIntervalSince(grammarStart)))s")

                // 5. Apply correction memory
                let finalText = corrections.applyCorrections(to: grammarFixed)

                // 6. Build result
                let totalElapsed = Int(Date().timeIntervalSince(totalStart) * 1000)
                NSLog("[TranscriptionViewModel] Total Processing Time: \(totalElapsed)ms")
                let words = finalText.components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }

                let result = JarvisTranscriptionResult(
                    id: UUID(), rawText: rawText, correctedText: finalText,
                    detectedLanguage: detectedLang.code, confidence: confidence,
                    durationSeconds: appState.recordingDuration,
                    transcriptionTimeMs: totalElapsed, timestamp: Date(),
                    words: words, wasCloudFallback: usedCloud
                )

                appState.lastResult = result
                appState.recentResults.insert(result, at: 0)
                if appState.recentResults.count > 50 { appState.recentResults.removeLast() }

                // 7. Insert at cursor
                NSLog("[TranscriptionViewModel] Inserting text: '\(finalText.prefix(20))...'")
                appState.recordingState = .inserting
                textInserter.insert(finalText)
                NSLog("[TranscriptionViewModel] Insertion call complete.")

                // 8. Confirmation
                appState.recordingState = .showingConfirmation(text: finalText)
                try? await Task.sleep(for: .seconds(1.5))
                appState.recordingState = .idle

            } catch {
                appState.recordingState = .error(message: "Transcription failed: \(error.localizedDescription)")
                dismissErrorAfterDelay()
            }

            // 9. Cleanup temp file
            cleanupTempFile()
        }
    }

    // MARK: - Audio callbacks

    private func onMaxDuration() {
        if case .recording = appState.recordingState { stopAndTranscribe() }
    }
    
    // MARK: - Correction

    func onCorrectionTrigger() {
        if appState.recordingState == .idle, appState.lastResult != nil {
            appState.recordingState = .showingCorrection
        }
    }

    func submitCorrection(wrong: String, correct: String, alwaysReplace: Bool) {
        let lang = appState.lastResult?.detectedLanguage ?? "en"
        corrections.addCorrection(wrong: wrong, correct: correct, language: lang, alwaysReplace: alwaysReplace)
        appState.recordingState = .idle
    }

    func dismissCorrection() {
        appState.recordingState = .idle
    }

    // MARK: - Helpers

    private func cleanupTempFile() {
        if let url = lastAudioURL {
            try? FileManager.default.removeItem(at: url)
            lastAudioURL = nil
        }
    }

    private func dismissErrorAfterDelay() {
        Task {
            try? await Task.sleep(for: .seconds(3))
            if case .error = appState.recordingState {
                appState.recordingState = .idle
            }
        }
    }

    // For settings view
    var correctionService: CorrectionMemoryService { corrections }

    func switchModel(to modelId: String) async {
        appState.recordingState = .downloadingModel(progress: 0)
        do {
            try await whisper.switchModel(to: modelId)
            appState.modelReady = true
            appState.recordingState = .idle
        } catch {
            appState.recordingState = .error(message: "Model switch failed: \(error.localizedDescription)")
            dismissErrorAfterDelay()
        }
    }
}
