import AppKit
import ApplicationServices
import SwiftUI

final class AppState: ObservableObject {
    @Published var config: AppConfig {
        didSet {
            guard config != oldValue else { return }
            save()
            apply()
        }
    }
    @Published private(set) var hasAccess = false
    /// Mens du velger en ny tast i innstillingene er motoren pauset.
    @Published var isRecording = false {
        didSet { apply() }
    }

    let engine = InputEngine()
    private var accessTimer: Timer?
    private static let storageKey = "config.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(AppConfig.self, from: data),
           !saved.profiles.isEmpty {
            config = saved
        } else {
            config = .makeDefault()
        }

        engine.onToggleHotkey = { [weak self] in self?.toggleFromHotkey() }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        hasAccess = AXIsProcessTrustedWithOptions(options)
        if hasAccess { engine.start() }
        apply()

        accessTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshAccess()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { Updater.check(silent: true) }
    }

    // MARK: - Profiler

    var activeProfileIndex: Int {
        config.profiles.firstIndex { $0.id == config.activeProfileID } ?? 0
    }

    var activeProfile: Profile { config.profiles[activeProfileIndex] }

    func addProfile() {
        let profile = Profile(name: "Profil \(config.profiles.count + 1)", mappings: [Mapping()])
        config.profiles.append(profile)
        config.activeProfileID = profile.id
    }

    func deleteActiveProfile() {
        guard config.profiles.count > 1 else { return }
        var next = config
        next.profiles.remove(at: activeProfileIndex)
        next.activeProfileID = next.profiles[0].id
        config = next
    }

    func addMapping() {
        config.profiles[activeProfileIndex].mappings.append(Mapping())
    }

    func removeMapping(_ id: UUID) {
        config.profiles[activeProfileIndex].mappings.removeAll { $0.id == id }
    }

    // MARK: - Av/på og tilgang

    func toggleFromHotkey() {
        config.enabled.toggle()
        NSSound(named: config.enabled ? "Pop" : "Bottle")?.play()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshAccess() {
        let trusted = AXIsProcessTrusted()
        if trusted != hasAccess { hasAccess = trusted }
        if trusted, !engine.isRunning {
            engine.start()
            apply()
        } else if !trusted, engine.isRunning {
            engine.stop()
        }
    }

    private func apply() {
        engine.configure(mappings: activeProfile.mappings, active: config.enabled && !isRecording)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
