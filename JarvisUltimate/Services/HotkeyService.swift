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

    private let rightOptionKeyCode: UInt16 = 0x40
    private let correctionKeyCode: UInt16 = 8  // C key
    private let correctionModifiers: UInt = 0x180100  // Cmd + Shift

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
        // Opening System Settings to let user re-grant permission
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
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
        let isRightOption = (event.modifierFlags.rawValue & UInt(rightOptionKeyCode)) != 0
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
        
        // Correction: Cmd+Shift+C
        if event.keyCode == correctionKeyCode && mods == correctionModifiers {
            NSLog("[HotkeyService] Correction trigger")
            onCorrectionTrigger?()
        }
    }
}
