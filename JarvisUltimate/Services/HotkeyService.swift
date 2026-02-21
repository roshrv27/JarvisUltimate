import AppKit
import ApplicationServices
import SwiftUI
import Observation

final class HotkeyService {
    private var flagsMonitor: Any?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    var onCorrectionTrigger: (() -> Void)?
    var onPTTStart: (() -> Void)?
    var onPTTEnd: (() -> Void)?

    private var isPTTActive = false
    private var lastOptionTime: TimeInterval = 0

    func start() {
        requestAccessibilityIfNeeded()
        registerMonitors()
    }

    func stop() {
        if let fm = flagsMonitor { NSEvent.removeMonitor(fm) }
        if let gm = globalMonitor { NSEvent.removeMonitor(gm) }
        if let lm = localMonitor { NSEvent.removeMonitor(lm) }
        flagsMonitor = nil
        globalMonitor = nil
        localMonitor = nil
    }

    func reregister() {
        stop()
        registerMonitors()
    }

    @discardableResult
    func requestAccessibilityIfNeeded() -> Bool {
        let isTrusted = AXIsProcessTrusted()
        if !isTrusted {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        return isTrusted
    }

    func resetAccessibilityDatabase() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.jarvisultimate.app"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleID]
        try? process.run()
    }

    private func registerMonitors() {
        // PTT: Right Option (flagsChanged)
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        
        // Correction: Cmd+Shift+C
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
            return event
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let isRightOption = (event.modifierFlags.rawValue & 0x40) != 0
        let isOptionPressed = event.modifierFlags.contains(.option)
        
        if isRightOption && isOptionPressed {
            let now = NSDate.timeIntervalSinceReferenceDate
            let diff = now - lastOptionTime
            
            // Double press detection
            if diff < 0.4 && !isPTTActive {
                NSLog("[HotkeyService] PTT Started (Right Option)")
                isPTTActive = true
                onPTTStart?()
            }
            lastOptionTime = now
        } else if !isOptionPressed {
            if isPTTActive {
                NSLog("[HotkeyService] PTT Ended")
                isPTTActive = false
                onPTTEnd?()
            }
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
        
        // Correction: Cmd+Shift+C (keyCode 8 = C)
        if event.keyCode == 8 && mods == 0x180100 {
            NSLog("[HotkeyService] Correction trigger")
            onCorrectionTrigger?()
        }
    }
}
