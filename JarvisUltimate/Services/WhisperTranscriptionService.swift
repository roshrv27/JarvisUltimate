import Foundation
import WhisperKit
import CoreML

final class WhisperTranscriptionService {
    private var whisperKit: WhisperKit?
    var onDownloadProgress: ((Double) -> Void)?

    private func modelCachePath() -> String {
        let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JarvisUltimate/Models")
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return path.path
    }

    func loadModel() async throws {
        let modelName = AppSettings.shared.selectedModel
        let cacheBase = URL(fileURLWithPath: modelCachePath())
        NSLog("[WhisperService] loadModel started for \(modelName)")
        
        let modelFolderURL = try await WhisperKit.download(
            variant: modelName,
            downloadBase: cacheBase,
            progressCallback: { [weak self] progress in
                let downloaded = progress.fractionCompleted
                self?.onDownloadProgress?(downloaded)
            }
        )
        NSLog("[WhisperService] Download/Verify finished at \(modelFolderURL.path)")
        
        let config = WhisperKitConfig(
            model: modelName,
            modelFolder: modelFolderURL.path,
            computeOptions: ModelComputeOptions(audioEncoderCompute: .cpuAndGPU, textDecoderCompute: .cpuAndGPU),
            verbose: false,
            logLevel: .none,
            prewarm: false
        )
        
        NSLog("[WhisperService] Initializing WhisperKit...")
        whisperKit = try await WhisperKit(config)
        NSLog("[WhisperService] WhisperKit READY")
    }

    func transcribe(audioURL: URL, audioSamples: [Float]? = nil, promptBias: String?) async throws
        -> (text: String, language: String, confidence: Double) {
        guard let wk = whisperKit else { throw TranscriptionError.modelNotLoaded }

        // Start timing
        let start = Date()
        NSLog("[WhisperService] Transcription started (samples: \(audioSamples?.count ?? 0))...")

        // DecodingOptions: Use Greedy Search (temperature 0.0) for significant speedup
        let options = DecodingOptions(
            task: .transcribe,
            language: nil,
            temperature: 0.0,
            detectLanguage: true,
            skipSpecialTokens: true
        )

        let results: [TranscriptionResult]
        if let samples = audioSamples, !samples.isEmpty {
            results = try await wk.transcribe(audioArray: samples, decodeOptions: options)
        } else {
            results = try await wk.transcribe(audioPath: audioURL.path, decodeOptions: options)
        }
        
        let elapsed = Date().timeIntervalSince(start)
        NSLog("[WhisperService] Transcription finished in \(String(format: "%.2f", elapsed))s")

        guard let result = results.first else {
            throw TranscriptionError.emptyResult
        }

        let text = result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let language = result.language

        // Compute average confidence from segments
        let segments = result.segments
        let avgLogProb: Float
        if segments.isEmpty {
            avgLogProb = -1.0
        } else {
            avgLogProb = segments.map(\TranscriptionSegment.avgLogprob).reduce(0, +) / Float(segments.count)
        }

        // avgLogProb is typically in range [-1, 0], normalize to [0, 1]
        let confidence = Double(min(max((avgLogProb + 1.0) / 1.0, 0), 1))

        if confidence < 0.4 {
            throw TranscriptionError.lowConfidence(text: text, language: language)
        }

        return (text, language, confidence)
    }

    func switchModel(to modelId: String) async throws {
        whisperKit = nil
        AppSettings.shared.selectedModel = modelId
        try await loadModel()
    }

    var isModelLoaded: Bool { whisperKit != nil }

    enum TranscriptionError: Error {
        case modelNotLoaded
        case emptyResult
        case lowConfidence(text: String, language: String)
    }
}
