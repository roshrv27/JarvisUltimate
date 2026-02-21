import Foundation
import WhisperKit

print("Test program starting")
let path = "/Users/rv/Library/Application Support/JarvisUltimate/Models/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3-v20240930_turbo_632MB"
let folderURL = URL(fileURLWithPath: path)
let config = WhisperKitConfig(model: "openai_whisper-large-v3-v20240930_turbo_632MB", modelFolder: folderURL.path, computeOptions: ModelComputeOptions(audioEncoderCompute: .cpuAndGPU, textDecoderCompute: .cpuAndGPU), verbose: true, logLevel: .debug)
Task {
    print("Loading model...")
    do {
        let wk = try await WhisperKit(config)
        print("Model loaded successfully")
        exit(0)
    } catch {
        print("Failed to load: \(error)")
        exit(1)
    }
}
RunLoop.main.run()
