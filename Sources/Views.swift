import AppKit
import SwiftUI

@main
struct TurboTastApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environmentObject(state)
        } label: {
            Image(systemName: state.config.enabled ? "bolt.fill" : "bolt.slash")
        }

        Window("TurboTast", id: "settings") {
            SettingsView().environmentObject(state)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

// MARK: - Menylinje

struct MenuContent: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Aktiv", isOn: $state.config.enabled)
            .keyboardShortcut("m", modifiers: [.command, .control, .option])

        if !state.hasAccess {
            Button("⚠️ Mangler tilgang – klikk for å fikse") { state.openAccessibilitySettings() }
        }

        Divider()

        Picker("Profil", selection: $state.config.activeProfileID) {
            ForEach(state.config.profiles) { Text($0.name).tag($0.id) }
        }

        Divider()

        Button("Innstillinger…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        Button("Se etter oppdateringer…") { Updater.check(silent: false) }

        Divider()

        Text("TurboTast \(Updater.currentVersion)")

        Button("Avslutt TurboTast") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

// MARK: - Innstillinger

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !state.hasAccess { AccessBanner() }

            HStack {
                Toggle(isOn: $state.config.enabled) {
                    Text("TurboTast er aktiv").font(.headline)
                }
                .toggleStyle(.switch)
                Spacer()
                Text("Av/på hvor som helst: ⌃⌥⌘M")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Picker("Profil:", selection: $state.config.activeProfileID) {
                    ForEach(state.config.profiles) { Text($0.name).tag($0.id) }
                }
                .frame(maxWidth: 240)
                TextField("Navn på profil", text: $state.config.profiles[state.activeProfileIndex].name)
                    .frame(width: 170)
                Button { state.addProfile() } label: { Image(systemName: "plus") }
                    .help("Ny profil")
                Button { state.deleteActiveProfile() } label: { Image(systemName: "trash") }
                    .help("Slett denne profilen")
                    .disabled(state.config.profiles.count < 2)
                Spacer()
            }

            Divider()

            HStack(spacing: 12) {
                Text("På").frame(width: 32, alignment: .leading)
                Text("Tast / klikk").frame(width: 140, alignment: .leading)
                Text("Modus").frame(width: 200, alignment: .leading)
                Text("Antall").frame(width: 100, alignment: .leading)
                Text("Pause mellom trykk").frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)

            VStack(spacing: 8) {
                ForEach($state.config.profiles[state.activeProfileIndex].mappings) { $mapping in
                    MappingRow(mapping: $mapping) { state.removeMapping(mapping.id) }
                }
            }

            Button { state.addMapping() } label: {
                Label("Legg til tast eller museklikk", systemImage: "plus.circle.fill")
            }

            Text("**Ganger opp:** ett trykk blir til så mange trykk som «Antall». **Hold for spam:** trykker om og om igjen mens du holder inne. Kombinasjoner med ⌘, ⌃ eller ⌥ blir aldri ganget opp.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 760)
    }
}

struct AccessBanner: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("TurboTast trenger tilgang").bold()
                Text("Systeminnstillinger → Personvern og sikkerhet → Tilgjengelighet → slå på TurboTast.")
                    .font(.callout)
                Text("Står den allerede på (f.eks. etter en oppdatering)? Fjern den med «–» og legg den til igjen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Åpne innstillinger") { state.openAccessibilitySettings() }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct MappingRow: View {
    @Binding var mapping: Mapping
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $mapping.enabled)
                .labelsHidden()
                .frame(width: 32, alignment: .leading)

            TriggerPicker(trigger: $mapping.trigger)
                .frame(width: 140)

            Picker("", selection: $mapping.mode) {
                ForEach(RepeatMode.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 200)

            Group {
                if mapping.mode == .multiply {
                    Stepper(value: $mapping.count, in: 2...1000) {
                        Text("\(mapping.count)×").monospacedDigit()
                    }
                } else {
                    Text("mens du holder").foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, alignment: .leading)

            Slider(value: delayBinding, in: 1...(500.0).squareRoot())
            Text("\(mapping.delayMs) ms")
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)

            Button(action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Fjern")
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .opacity(mapping.enabled ? 1 : 0.55)
    }

    /// Kvadratisk skala, så det er lett å stille inn små verdier (1–50 ms) nøyaktig.
    private var delayBinding: Binding<Double> {
        Binding(
            get: { Double(mapping.delayMs).squareRoot() },
            set: { mapping.delayMs = max(1, Int(($0 * $0).rounded())) }
        )
    }
}

struct TriggerPicker: View {
    @Binding var trigger: Trigger?
    @EnvironmentObject var state: AppState
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Menu {
            Button("Tastatur – trykk en tast…") { startRecording() }
            Button("Venstreklikk (mus)") { trigger = Trigger(kind: .mouseLeft) }
            Button("Høyreklikk (mus)") { trigger = Trigger(kind: .mouseRight) }
        } label: {
            if recording {
                Text("Trykk en tast…")
            } else if let trigger {
                Label(trigger.displayName, systemImage: trigger.symbolName)
            } else {
                Text("Velg…")
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        stopRecording()
        recording = true
        state.isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode != 53 { // Esc avbryter
                trigger = Trigger(kind: .key, keyCode: event.keyCode)
            }
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        if state.isRecording { state.isRecording = false }
    }
}
