import AppKit

let mods = NSEvent.ModifierFlags([.command, .shift]).rawValue
let masked = mods & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue

print("Cmd+Shift: \(String(masked, radix: 16))")
print("Cmd+Option: \(String(NSEvent.ModifierFlags([.command, .option]).rawValue & NSEvent.ModifierFlags.deviceIndependentFlagsMask.rawValue, radix: 16))")
