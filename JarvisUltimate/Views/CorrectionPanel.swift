import AppKit
import SwiftUI

final class CorrectionPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        self.contentView = contentView
        centerOnScreen()
    }

    // CAN become key -- this panel needs TextField input
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        let rect = screen.visibleFrame
        let x = rect.midX - frame.width / 2
        let y = rect.midY - frame.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
