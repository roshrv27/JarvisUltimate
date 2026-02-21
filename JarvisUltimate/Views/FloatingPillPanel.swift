import AppKit
import SwiftUI

final class FloatingPillPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 52),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        self.contentView = contentView
        centerOnScreen()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        let rect = screen.visibleFrame
        let x = rect.midX - frame.width / 2
        let y = rect.maxY - frame.height - 80
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func updateSize(width: CGFloat, height: CGFloat) {
        let origin = frame.origin
        let newX = origin.x + (frame.width - width) / 2
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(NSRect(x: newX, y: origin.y, width: width, height: height), display: true)
        }
    }
}
