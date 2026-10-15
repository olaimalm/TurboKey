import Foundation

enum TriggerKind: String, Codable {
    case key, mouseLeft, mouseRight
}

/// Hva som utløser en gjentakelse: en tast (keyCode) eller en museknapp.
struct Trigger: Codable, Hashable {
    var kind: TriggerKind
    var keyCode: UInt16 = 0
}

enum RepeatMode: String, Codable, CaseIterable, Identifiable {
    /// Ett trykk blir til `count` trykk.
    case multiply
    /// Trykker om og om igjen så lenge tasten holdes inne.
    case hold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .multiply: return "Ganger opp"
        case .hold: return "Hold for spam"
        }
    }
}

struct Mapping: Codable, Identifiable, Equatable {
    var id = UUID()
    var enabled = true
    var trigger: Trigger?
    var mode: RepeatMode = .multiply
    /// Totalt antall trykk per ekte trykk (inkludert ditt eget).
    var count = 10
    /// Pause mellom hvert trykk (eller intervall i hold-modus).
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
            name: "Standard",
            mappings: [Mapping(trigger: Trigger(kind: .key, keyCode: 13))] // W
        )
        return AppConfig(profiles: [profile], activeProfileID: profile.id, enabled: false)
    }
}
