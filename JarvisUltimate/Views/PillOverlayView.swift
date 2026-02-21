import SwiftUI

struct PillOverlayView: View {
    var appState: AppState

    @State private var glowAnimation = false
    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            // Glassmorphism background
            RoundedRectangle(cornerRadius: 26)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(borderGradient, lineWidth: isRecording ? 2 : 1)
                )
                .shadow(color: glowColor.opacity(glowAnimation ? 0.6 : 0.1), radius: glowAnimation ? 20 : 5)

            // State-specific content
            Group {
                switch appState.recordingState {
                case .downloadingModel(let progress):
                    downloadContent(progress: progress)
                case .recording:
                    recordingContent
                case .transcribing:
                    transcribingContent
                case .inserting:
                    insertingContent
                case .showingConfirmation(let text):
                    confirmationContent(text)
                case .error(let message):
                    errorContent(message)
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(width: pillWidth, height: pillHeight)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }

    // MARK: - State Views

    private func downloadContent(progress: Double) -> some View {
        HStack(spacing: 8) {
            if progress >= 0.99 {
                ProgressView()
                    .controlSize(.small)
                    .tint(.cyan)
                Text("Optimizing Model...")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ProgressView(value: progress)
                    .frame(width: 80)
                    .tint(.cyan)
                Text("Loading: \(Int(progress * 100))%")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var recordingContent: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .opacity(glowAnimation ? 1 : 0.4)
            WaveformView(amplitudes: appState.currentAmplitudes)
                .frame(width: 60)
            Text(formattedDuration)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var transcribingContent: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(.cyan)
            Text("Processing...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var insertingContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.cursor")
                .foregroundStyle(.cyan)
            Text("Jarvis Inserting...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func confirmationContent(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Jarvis Inserted")
                .font(.caption).fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.9))
            if let lang = appState.lastResult?.detectedLanguage {
                Text(lang.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    private func errorContent(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
        }
    }

    // MARK: - Computed Properties

    private var isRecording: Bool {
        if case .recording = appState.recordingState { return true }
        return false
    }

    private var pillWidth: CGFloat {
        switch appState.recordingState {
        case .downloadingModel: return 220
        case .recording: return 180
        case .transcribing, .inserting: return 160
        case .showingConfirmation: return 200
        case .error: return 300
        default: return 160
        }
    }

    private var pillHeight: CGFloat { 52 }

    private var glowColor: Color {
        switch appState.recordingState {
        case .recording: return .cyan
        case .error: return .red
        default: return .blue
        }
    }

    private var borderGradient: AngularGradient {
        AngularGradient(
            colors: [.cyan, .blue, .purple, .cyan],
            center: .center,
            angle: .degrees(rotationAngle)
        )
    }

    private var formattedDuration: String {
        let total = Int(appState.recordingDuration)
        let max = AppSettings.shared.maxRecordingSeconds
        let mins = total / 60
        let secs = total % 60
        if max > 0 {
            let maxMins = max / 60
            let maxSecs = max % 60
            return String(format: "%d:%02d / %d:%02d", mins, secs, maxMins, maxSecs)
        }
        return String(format: "%d:%02d", mins, secs)
    }
}
