import SwiftUI
import ApplicationServices
import AVFoundation

struct SettingsView: View {
    var viewModel: TranscriptionViewModel
    
    var body: some View {
        TabView {
            GeneralTab(viewModel: viewModel)
                .tabItem { Label("General", systemImage: "gear") }
            HotkeyTab()
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
            CorrectionsTab()
                .tabItem { Label("Corrections", systemImage: "text.badge.checkmark") }
        }
        .frame(width: 500, height: 420)
    }
}

// MARK: - General Tab

struct GeneralTab: View {
    var viewModel: TranscriptionViewModel
    @Bindable private var settings = AppSettings.shared
    @State private var selectedModelIndex: Int = 1
    @State private var selectedDurationIndex: Int = 1
    @State private var trustStatus: Bool = false
    @State private var micStatus: AVAuthorizationStatus = .notDetermined

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Jarvis Ultimate Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.top, 13)
                .padding(.bottom, 8)
            
            // Transcription Model Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Transcription Model")
                    .font(.headline)
                
                Picker("", selection: $selectedModelIndex) {
                    ForEach(0..<AppSettings.modelPresets.count, id: \.self) { index in
                        let preset = AppSettings.modelPresets[index]
                        VStack(alignment: .leading) {
                            Text(preset.name)
                            Text("\(preset.description) • \(preset.size)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedModelIndex) { _, newValue in
                    settings.selectedModel = AppSettings.modelPresets[newValue].model
                }
                
                Text("Select a Whisper model for transcription.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            
            Divider()
                .padding(.vertical, 12)
            
            // Recording Duration Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Recording Duration")
                    .font(.headline)
                
                Picker("", selection: $selectedDurationIndex) {
                    ForEach(0..<AppSettings.durationPresets.count, id: \.self) { index in
                        let preset = AppSettings.durationPresets[index]
                        let label = preset.maxSec > 0 ? "\(preset.name) (\(preset.maxSec)s)" : preset.name
                        Text(label).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedDurationIndex) { _, newValue in
                    let preset = AppSettings.durationPresets[newValue]
                    settings.maxRecordingSeconds = preset.maxSec
                }
                
                Text("Maximum recording duration. Recording will stop automatically after this time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            
            Divider()
                .padding(.vertical, 12)
            
            // Permissions Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Permissions")
                    .font(.headline)
                
                // Accessibility
                HStack {
                    Image(systemName: trustStatus ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(trustStatus ? .green : .red)
                    Text(trustStatus ? "Accessibility: Granted" : "Accessibility: Required")
                }
                
                if !trustStatus {
                    Button("Request Accessibility Permission") {
                        viewModel.requestAccessibility()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button("Open Accessibility Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
                .buttonStyle(.bordered)
                
                Button("Refresh Permission Status") {
                    viewModel.requestAccessibility()
                    checkPermissions()
                }
                .buttonStyle(.bordered)
                
                Divider()
                
                // Microphone
                HStack {
                    Image(systemName: micStatus == .authorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(micStatus == .authorized ? .green : .red)
                    Text(micStatus == .authorized ? "Microphone: Granted" : "Microphone: Required")
                }
                
                if micStatus != .authorized {
                    Button("Open Microphone Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Divider()
                
                Button("Reset Accessibility Trust") {
                    viewModel.resetAccessibility()
                    trustStatus = false
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .onAppear {
            if let idx = AppSettings.modelPresets.firstIndex(where: { $0.model == settings.selectedModel }) {
                selectedModelIndex = idx
            }
            if let idx = AppSettings.durationPresets.firstIndex(where: { $0.maxSec == settings.maxRecordingSeconds }) {
                selectedDurationIndex = idx
            } else {
                selectedDurationIndex = 1
            }
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        trustStatus = AXIsProcessTrustedWithOptions(options)
        micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }
}

// MARK: - Hotkey Tab

struct HotkeyTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Jarvis Ultimate Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.top, 0)
                .padding(.bottom, 8)
            
            // Push-to-Talk Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Push-to-Talk Recording")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.cyan)
                    Text("Double-press and hold Right Option (⌥)")
                        .font(.callout)
                }
                
                Text("1. Double-press and hold Right Option key\n2. Speak your message\n3. Release to transcribe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            
            Divider()
                .padding(.vertical, 12)
            
            // Correction Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Correction Trigger")
                    .font(.headline)
                
                Text("⌘⇧C (Command+Shift+C)")
                    .font(.callout)
                
                Text("Trigger correction for last transcription")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
}

// MARK: - Corrections Tab

struct CorrectionsTab: View {
    private let corrections = CorrectionMemoryService()
    @State private var entries: [CorrectionEntry] = []
    @State private var searchText = ""

    var filteredEntries: [CorrectionEntry] {
        if searchText.isEmpty { return entries }
        return entries.filter {
            $0.wrongText.localizedCaseInsensitiveContains(searchText) ||
            $0.correctText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Jarvis Ultimate Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.top, 0)
                .padding(.bottom, 8)
            
            TextField("Search corrections...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 20)
            
            // Count and buttons
            HStack {
                Text("\(entries.count) corrections")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Export") { exportCorrections() }
                    .buttonStyle(.bordered)
                Button("Import") { importCorrections() }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            
            // List
            List {
                ForEach(filteredEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.wrongText)
                                .foregroundStyle(.red.opacity(0.8))
                                .strikethrough()
                            Image(systemName: "arrow.right")
                                .font(.caption)
                            Text(entry.correctText)
                                .foregroundStyle(.green)
                                .fontWeight(.medium)
                        }
                        HStack(spacing: 4) {
                            Text(entry.language.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(.white.opacity(0.1))
                                .clipShape(Capsule())
                            Text("\(entry.occurrenceCount)×")
                                .font(.caption2)
                            if entry.alwaysReplace {
                                Text("Auto")
                                    .font(.caption2)
                                    .foregroundStyle(.cyan)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        corrections.removeCorrection(id: filteredEntries[index].id)
                    }
                    refreshEntries()
                }
            }
        }
        .onAppear {
            corrections.load()
            refreshEntries()
        }
    }

    private func refreshEntries() {
        entries = corrections.allCorrections()
    }

    private func exportCorrections() {
        guard let data = corrections.exportJSON() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "jarvis_corrections.json"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    private func importCorrections() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url) {
                corrections.importJSON(data)
                refreshEntries()
            }
        }
    }
}
