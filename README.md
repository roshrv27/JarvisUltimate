# Jarvis Ultimate

> **On-device voice-to-text for macOS**, optimized for Apple Silicon. Powered by WhisperKit (CoreML) with OpenAI cloud fallback.

## ✨ Features

- 🎙️ **Local Transcription**: WhisperKit running on Apple Neural Engine — fast, private, no internet needed
- ☁️ **Cloud Fallback**: Automatic OpenAI Whisper API fallback for low-confidence results
- 🌍 **Auto Language Detection**: 99 languages auto-detected via Whisper + NLLanguageRecognizer
- ✏️ **Grammar Correction**: Automatic spelling, grammar, and punctuation fixes
- 🧠 **Correction Memory**: Learns your corrections and auto-replaces in future transcriptions
- 💊 **Futuristic Pill Overlay**: Non-focus-stealing glassmorphic overlay with real-time waveform
- ⌨️ **Cursor Insertion**: Text inserted directly at cursor in the active application
- 🔧 **Customizable Hotkeys**: Configurable record and correction trigger keys

## 🖥️ Requirements

- **macOS 14+ (Sonoma)** or later
- **Apple Silicon Mac** (M1/M2/M3/M4)
- **Xcode 15+** (for building)

## 🔨 Build

1. Clone this repository
2. Install XcodeGen (if not already):
   ```bash
   brew install xcodegen
   ```
3. Generate the Xcode project:
   ```bash
   cd JarvisUltimate
   xcodegen generate
   ```
4. Open `JarvisUltimate.xcodeproj` in Xcode
5. WhisperKit package dependency will resolve automatically
6. Select **"My Mac"** as the run destination
7. Press **Cmd+R** to build and run

## 🚀 First Launch

1. **Grant Microphone permission** when prompted
2. **Grant Accessibility permission**: System Settings > Privacy & Security > Accessibility
3. **Wait for model download** (~632MB, 1-2 minutes on first launch)

## 📖 Usage

| Hotkey | Action |
|--------|--------|
| `Cmd+Shift+Space` | Start/stop recording (text inserted at cursor) |
| `Cmd+Shift+C` | Correct last transcription |

- Click the **menu bar icon** (🎙️) for recent transcriptions and settings
- Transcriptions are automatically inserted at your cursor position in any app
- If a word is transcribed incorrectly, press `Cmd+Shift+C` to open the correction panel

## ⚙️ Settings

- **General**: Choose transcription model (accuracy vs speed), recording duration, silence detection
- **Hotkeys**: Customize keyboard shortcuts, check Accessibility permission
- **Cloud**: Add OpenAI API key for cloud fallback
- **Corrections**: View, search, export/import your correction dictionary

## 🔐 Permissions & Security

- **No App Sandbox**: The app runs without sandbox because Accessibility API (`AXUIElement`) and simulated keystrokes (`CGEvent.post`) require it
- **Hardened Runtime**: Code-signed with hardened runtime for security
- **API Key Storage**: OpenAI API key stored securely in macOS Keychain

## ⚠️ Hotkey Conflict Note

If `Cmd+Shift+Space` conflicts with macOS input source switching, change it in **Settings > Hotkeys**.

## 🌐 Supported Languages

99 languages auto-detected by Whisper, including English, Spanish, French, German, Chinese, Japanese, Hindi, Arabic, and many more.

## 📄 License

MIT License
