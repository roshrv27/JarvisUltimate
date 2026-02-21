import AppKit

let mods = NSEvent.ModifierFlags([.command, .shift]).rawValue
print("Cmd+Shift: \(String(mods, radix: 16))")
print("Option: \(String(NSEvent.ModifierFlags.option.rawValue, radix: 16))")
