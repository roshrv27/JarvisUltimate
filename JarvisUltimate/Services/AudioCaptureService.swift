import AVFoundation

final class AudioCaptureService {
    var onAmplitude: ((Float) -> Void)?
    var onMaxDurationReached: (() -> Void)?

    private var engine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var tempFileURL: URL?
    private var maxDurationTimer: Timer?
    private let settings = AppSettings.shared

    private var samples: [Float] = []
    
    // Target format: 16kHz, mono, Float32 (what Whisper expects)
    private let whisperFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    func getRecordedSamples() -> [Float] {
        return samples
    }
    
    private var microphonePermissionGranted: Bool = false
    
    func requestMicrophonePermission() async -> Bool {
        // Check if already granted
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphonePermissionGranted = true
            return true
        case .notDetermined:
            // Request permission
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    self.microphonePermissionGranted = granted
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }
    
    func requestMicrophonePermissionIfNeeded() async -> Bool {
        // Just return true if already granted, don't ask again
        if microphonePermissionGranted {
            return true
        }
        return await requestMicrophonePermission()
    }

    func startRecording() throws {
        samples.removeAll()
        let engine = AVAudioEngine()
        self.engine = engine

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create temp WAV file
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        tempFileURL = url
        audioFile = try AVAudioFile(
            forWriting: url,
            settings: whisperFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        // Audio converter: input device format -> 16kHz mono
        guard let converter = AVAudioConverter(from: inputFormat, to: whisperFormat) else {
            throw AudioError.converterFailed
        }

        // Install tap on input node (native device format)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) {
            [weak self] buffer, time in
            guard let self else { return }

            // Convert to 16kHz mono
            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * (16000.0 / inputFormat.sampleRate)
            )
            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: self.whisperFormat, frameCapacity: frameCount
            ) else { return }

            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            // Copy to in-memory array
            if let channelData = convertedBuffer.floatChannelData?[0] {
                let count = Int(convertedBuffer.frameLength)
                let array = Array(UnsafeBufferPointer(start: channelData, count: count))
                self.samples.append(contentsOf: array)
            }

            // Write to WAV file
            try? self.audioFile?.write(from: convertedBuffer)

            // Calculate RMS amplitude for waveform
            if let channelData = convertedBuffer.floatChannelData?[0] {
                let count = Int(convertedBuffer.frameLength)
                var rms: Float = 0
                for i in 0..<count { rms += channelData[i] * channelData[i] }
                rms = sqrt(rms / Float(max(count, 1)))
                let normalizedAmplitude = min(rms * 15.0, 1.0)
                self.onAmplitude?(normalizedAmplitude)
            }
        }

        try engine.start()

        // Max duration timer - stops recording after set time limit
        let maxSec = settings.maxRecordingSeconds
        if maxSec > 0 {
            maxDurationTimer = Timer.scheduledTimer(
                withTimeInterval: TimeInterval(maxSec), repeats: false
            ) { [weak self] _ in
                self?.onMaxDurationReached?()
            }
        }
    }

    func stopRecording() -> URL? {
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        audioFile = nil  // closes the file
        return tempFileURL
    }

    func cancelRecording() {
        let url = stopRecording()
        if let url { try? FileManager.default.removeItem(at: url) }
    }

    enum AudioError: Error {
        case converterFailed
    }
}
