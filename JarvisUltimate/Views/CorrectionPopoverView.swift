import SwiftUI

struct CorrectionPopoverView: View {
    let result: JarvisTranscriptionResult
    @State private var selectedWord: String?
    @State private var correctedText: String = ""
    @State private var alwaysReplace: Bool = true
    var onSubmit: (_ wrong: String, _ correct: String, _ always: Bool) -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Correct a word")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("Tap the incorrectly transcribed word:")
                .font(.caption).foregroundStyle(.secondary)

            FlowLayout(spacing: 6) {
                ForEach(Array(result.words.enumerated()), id: \.offset) { _, word in
                    Text(word)
                        .font(.system(.body, design: .rounded))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(
                            word == selectedWord
                                ? Color.cyan.opacity(0.3)
                                : Color.white.opacity(0.08)
                        )
                        .clipShape(Capsule())
                        .onTapGesture {
                            selectedWord = word
                            correctedText = ""
                        }
                }
            }

            if let selected = selectedWord {
                Divider()
                HStack {
                    Text("\"\(selected)\"")
                        .fontWeight(.medium)
                        .foregroundStyle(.red.opacity(0.8))
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    TextField("Correct word", text: $correctedText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                }
                Toggle("Always auto-replace in future", isOn: $alwaysReplace)
                    .font(.caption)
                HStack {
                    Button("Save Correction") {
                        if !correctedText.isEmpty {
                            onSubmit(selected, correctedText, alwaysReplace)
                        }
                    }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)

                    Button("Cancel", action: onDismiss)
                        .keyboardShortcut(.escape)
                }
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
