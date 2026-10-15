import Carbon
import Foundation

enum KeyNames {
    private static let special: [UInt16: String] = [
        36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc", 117: "Fwd Delete",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        76: "Keypad Enter",
    ]

    static func name(for keyCode: UInt16) -> String {
        if let name = special[keyCode] { return name }
        if let char = translate(keyCode), !char.trimmingCharacters(in: .whitespaces).isEmpty {
            return char.uppercased()
        }
        return "Key \(keyCode)"
    }

    /// Looks up the character the key produces with the current keyboard layout (e.g. Æ/Ø/Å on Norwegian).
    private static func translate(_ keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(
                layout, keyCode, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, chars.count, &length, &chars
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}

extension Trigger {
    var displayName: String {
        switch kind {
        case .mouseLeft: return "Left click"
        case .mouseRight: return "Right click"
        case .key: return KeyNames.name(for: keyCode)
        }
    }

    var symbolName: String {
        kind == .key ? "keyboard" : "computermouse"
    }
}
