import Foundation

enum TriggerKind: String, Codable {
    case key, mouseLeft, mouseRight
}

/// What triggers a repeat: a key (keyCode) or a mouse button.
struct Trigger: Codable, Hashable {
    var kind: TriggerKind
    var keyCode: UInt16 = 0
}

enum RepeatMode: String, Codable, CaseIterable, Identifiable {
    /// One press becomes `count` presses.
    case multiply
    /// Presses again and again for as long as the key is held down.
    case hold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .multiply: return "Multiply"
        case .hold: return "Hold to spam"
        }
    }
}

struct Mapping: Codable, Identifiable, Equatable {
    var id = UUID()
    var enabled = true
    var trigger: Trigger?
    var mode: RepeatMode = .multiply
    /// Total presses per real press (including your own).
    var count = 10
    /// Pause between presses (or the interval in hold mode).
    var delayMs = 10
}

struct Profile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var mappings: [Mapping]
}

struct AppConfig: Codable, Equatable {
    var profiles: [Profile]
    var activeProfileID: UUID
    var enabled: Bool

    static func makeDefault() -> AppConfig {
        let profile = Profile(
            name: "Default",
            mappings: [Mapping(trigger: Trigger(kind: .key, keyCode: 13))] // W
        )
        return AppConfig(profiles: [profile], activeProfileID: profile.id, enabled: false)
    }
}
