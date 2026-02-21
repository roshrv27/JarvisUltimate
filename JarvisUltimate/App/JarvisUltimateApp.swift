import SwiftUI

@main
struct JarvisUltimateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var coordinator = AppCoordinator()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            menuBarContent
        } label: {
            Image(systemName: menuBarIcon)
        }

        Window("Jarvis Ultimate Settings", id: "settings") {
            SettingsView(viewModel: coordinator.viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 500, height: 400)
    }

    // MARK: - Menu Bar Icon

    private var menuBarIcon: String {
        switch coordinator.appState.recordingState {
        case .recording: return "waveform.circle.fill"
        case .transcribing: return "ellipsis.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .downloadingModel: return "arrow.down.circle"
        default: return "mic.circle"
        }
    }

    // MARK: - Menu Bar Content

    @ViewBuilder
    private var menuBarContent: some View {
        switch coordinator.appState.recordingState {
        case .recording:
            Text("Recording...").foregroundStyle(.red)
        case .transcribing:
            Text("Transcribing...")
        case .downloadingModel(let progress):
            if progress >= 0.99 {
                Text("Optimizing Model...")
            } else {
                Text("Downloading model: \(Int(progress * 100))%")
            }
        default:
            Text("Jarvis Ultimate — Ready")
        }

        Divider()

        if !coordinator.appState.recentResults.isEmpty {
            ForEach(coordinator.appState.recentResults.prefix(5)) { result in
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.correctedText, forType: .string)
                } label: {
                    Text(String(result.correctedText.prefix(50)))
                }
            }
            Divider()
        }

        Button("Settings...") {
            NSLog("[JarvisUltimateApp] Settings button clicked")
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Jarvis Ultimate") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
