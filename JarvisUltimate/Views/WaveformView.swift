import SwiftUI

struct WaveformView: View {
    let amplitudes: [Float]
    let barCount: Int = 24

    var body: some View {
        Canvas { context, size in
            let total = CGFloat(barCount)
            let barWidth = size.width / total * 0.65
            let gap = size.width / total * 0.35
            let samples = amplitudes.suffix(barCount)

            for (index, amplitude) in samples.enumerated() {
                let normalized = CGFloat(min(max(amplitude, 0), 1))
                let barHeight = max(normalized * size.height, 3) // min 3px for better look
                let x = CGFloat(index) * (barWidth + gap)
                let y = (size.height - barHeight) / 2
                let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                let opacity = 0.5 + Double(normalized) * 0.5
                context.fill(path, with: .color(.cyan.opacity(opacity)))
            }
        }
        .frame(height: 28)
    }
}
