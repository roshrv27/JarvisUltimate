import SwiftUI
import AppKit
import Observation

@MainActor
final class AppCoordinator {
    let appState: AppState
    let viewModel: TranscriptionViewModel
    
    private var pillPanel: FloatingPillPanel?
    private var correctionPanel: CorrectionPanel?
    
    init() {
        NSLog("[AppCoordinator] Initializing...")
        let state = AppState()
        self.appState = state
        self.viewModel = TranscriptionViewModel(appState: state)
        
        setupPanels()
        
        // Start the engine
        Task {
            await viewModel.bootstrap()
        }
        
        // Observe state changes
        observeState()
    }
    
    private func setupPanels() {
        let pillView = PillOverlayView(appState: appState)
        let pillHosting = NSHostingView(rootView: pillView)
        pillHosting.frame = NSRect(x: 0, y: 0, width: 220, height: 52)
        pillPanel = FloatingPillPanel(contentView: pillHosting)
        
        let corrView = CorrectionPopoverView(
            result: JarvisTranscriptionResult(
                id: UUID(), rawText: "", correctedText: "",
                detectedLanguage: "en", confidence: 1.0,
                durationSeconds: 0, transcriptionTimeMs: 0,
                timestamp: Date(), words: [], wasCloudFallback: false
            ),
            onSubmit: { [weak self] wrong, correct, always in
                self?.viewModel.submitCorrection(wrong: wrong, correct: correct, alwaysReplace: always)
            },
            onDismiss: { [weak self] in
                self?.viewModel.dismissCorrection()
            }
        )
        let corrHosting = NSHostingView(rootView: corrView)
        corrHosting.frame = NSRect(x: 0, y: 0, width: 380, height: 300)
        correctionPanel = CorrectionPanel(contentView: corrHosting)
    }
    
    private func observeState() {
        _ = withObservationTracking {
            appState.recordingState
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleStateChange(self.appState.recordingState)
                self.observeState() // Re-subscribe
            }
        }
    }
    
    private var lastStateCategory: String = ""
    
    private func handleStateChange(_ state: RecordingState) {
        let category = stateCategory(for: state)
        
        switch state {
        case .idle:
            pillPanel?.orderOut(nil)
            correctionPanel?.orderOut(nil)
            lastStateCategory = ""
            
        case .recording, .transcribing, .inserting, .showingConfirmation, .error, .downloadingModel:
            correctionPanel?.orderOut(nil)
            if pillPanel?.isVisible == false {
                pillPanel?.centerOnScreen()
                pillPanel?.orderFront(nil)
            }
            
            // Only update size and re-center if the category changed to avoid flickering
            if category != lastStateCategory {
                let width = pillWidth(for: state)
                pillPanel?.updateSize(width: width, height: 52)
                lastStateCategory = category
            }
            
        case .showingCorrection:
            pillPanel?.orderOut(nil)
            lastStateCategory = ""
            if let result = appState.lastResult {
                let corrView = CorrectionPopoverView(
                    result: result,
                    onSubmit: { [weak self] wrong, correct, always in
                        self?.viewModel.submitCorrection(wrong: wrong, correct: correct, alwaysReplace: always)
                    },
                    onDismiss: { [weak self] in
                        self?.viewModel.dismissCorrection()
                    }
                )
                let hostingView = NSHostingView(rootView: corrView)
                correctionPanel?.contentView = hostingView
                correctionPanel?.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func stateCategory(for state: RecordingState) -> String {
        switch state {
        case .idle: return "idle"
        case .downloadingModel: return "download"
        case .recording: return "record"
        case .transcribing: return "transcribe"
        case .inserting: return "insert"
        case .showingConfirmation: return "confirm"
        case .showingCorrection: return "correct"
        case .error: return "error"
        }
    }

    private func pillWidth(for state: RecordingState) -> CGFloat {
        switch state {
        case .downloadingModel: return 220
        case .recording: return 180
        case .transcribing, .inserting: return 160
        case .showingConfirmation: return 200
        case .error: return 300
        default: return 160
        }
    }
}
