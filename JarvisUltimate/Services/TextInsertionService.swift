import AppKit
import ApplicationServices

final class TextInsertionService {
    
    private func log(_ msg: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(msg)\n"
        
        let logsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JarvisUltimate/logs")
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        let logFile = logsDir.appendingPathComponent("insertion.log")
        
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
        NSLog("[TextInsertion] \(msg)")
    }

    func insert(_ text: String) {
        log("=== insert() called ===")
        log("Text: \(text)")
        
        // Wait for modifier keys to be released
        var retry = 0
        while retry < 10 {
            let mods = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods.isEmpty { break }
            usleep(50000)
            retry += 1
        }
        
        // Small delay to ensure target app has focus
        usleep(100000) // 100ms
        
        // Try accessibility API
        log("Trying accessibility API...")
        let success = insertViaAccessibility(text)
        
        if success {
            log("Accessibility API succeeded!")
            return
        }
        
        log("Accessibility API failed, trying clipboard fallback...")
        insertViaClipboard(text)
    }

    private func insertViaAccessibility(_ text: String) -> Bool {
        log("Creating system-wide accessibility element...")
        
        let systemWide = AXUIElementCreateSystemWide()
        
        // Get focused element
        var focusedElement: AnyObject?
        let err = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        log("AXUIElementCopyAttributeValue result: \(err.rawValue) (0 = success)")
        
        guard err == .success, let element = focusedElement else {
            log("FAILED: Could not get focused element")
            return false
        }
        
        let axElement = element as! AXUIElement
        
        // Get element role
        var role: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &role)
        log("Focused element role: \(role as? String ?? "unknown")")
        
        // Get selected text range to find cursor position
        var selectedRange: AnyObject?
        let rangeErr = AXUIElementCopyAttributeValue(
            axElement, 
            kAXSelectedTextRangeAttribute as CFString, 
            &selectedRange
        )
        
        var insertPosition: Int = 0
        
        if rangeErr == .success, let range = selectedRange {
            var rangeValue = CFRange()
            if AXValueGetValue(range as! AXValue, .cfRange, &rangeValue) {
                insertPosition = rangeValue.location
                log("Cursor/selection position: \(insertPosition), length: \(rangeValue.length)")
                
                // If there's a selection, replace it
                if rangeValue.length > 0 {
                    log("Replacing selection of length \(rangeValue.length)")
                }
            }
        } else {
            log("Could not get selected text range, defaulting to cursor position 0")
        }
        
        // Get current text value
        var currentValue: AnyObject?
        let valueErr = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &currentValue)
        
        if valueErr == .success, var currentString = currentValue as? String {
            log("Current text length: \(currentString.count)")
            
            // Insert at the correct position
            let prefix: String
            let suffix: String
            
            if insertPosition <= currentString.count {
                prefix = String(currentString.prefix(insertPosition))
                suffix = String(currentString.dropFirst(insertPosition))
            } else {
                // Cursor is beyond text length, append
                prefix = currentString
                suffix = ""
                insertPosition = currentString.count
            }
            
            let newValue = prefix + text + suffix
            log("Inserting at position \(insertPosition): prefix=\(prefix.count) chars, suffix=\(suffix.count) chars")
            
            // Set the new value
            let setResult = AXUIElementSetAttributeValue(
                axElement,
                kAXValueAttribute as CFString,
                newValue as CFTypeRef
            )
            
            if setResult == .success {
                // Move cursor to after inserted text
                let newCursorPos = insertPosition + text.count
                var newRange = CFRange(location: newCursorPos, length: 0)
                if let axNewRange = AXValueCreate(.cfRange, &newRange) {
                    AXUIElementSetAttributeValue(
                        axElement,
                        kAXSelectedTextRangeAttribute as CFString,
                        axNewRange
                    )
                }
                log("SUCCESS: Text inserted at position \(insertPosition)")
                return true
            } else {
                log("Set value failed: \(setResult.rawValue)")
            }
        }
        
        // Fallback: try just setting selected text
        log("Trying fallback: set selected text...")
        let result = AXUIElementSetAttributeValue(
            axElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        
        log("AXUIElementSetAttributeValue result: \(result.rawValue) (0 = success)")
        return result == .success
    }

    private func insertViaClipboard(_ text: String) {
        log("=== CLIPBOARD FALLBACK ===")
        
        let pb = NSPasteboard.general
        let oldContent = pb.string(forType: .string)

        pb.clearContents()
        pb.setString(text, forType: .string)
        
        log("Clipboard set, posting Cmd+V...")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let source = CGEventSource(stateID: .hidSystemState)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)!
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)

            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)!
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
            
            self?.log("Cmd+V posted")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pb.clearContents()
                if let old = oldContent {
                    pb.setString(old, forType: .string)
                }
            }
        }
    }
}
