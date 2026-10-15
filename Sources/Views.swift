import AppKit
import SwiftUI

@main
struct TurboKeyApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environmentObject(state)
        } label: {
            Image(systemName: state.config.enabled ? "bolt.fill" : "bolt.slash")
        }

        Window("TurboKey", id: "settings") {
            SettingsView().environmentObject(state)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

// MARK: - Menu bar

struct MenuContent: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Active", isOn: $state.config.enabled)
            .keyboardShortcut("m", modifiers: [.command, .control, .option])

        if !state.hasAccess {
            Button("⚠️ Missing access – click to fix") { state.openAccessibilitySettings() }
        }

        Divider()

        Picker("Profile", selection: $state.config.activeProfileID) {
            ForEach(state.config.profiles) { Text($0.name).tag($0.id) }
        }

        Divider()

        Button("Settings…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        Button("Check for Updates…") { Updater.check(silent: false) }

        Divider()

        Text("TurboKey \(Updater.currentVersion)")

        Button("Quit TurboKey") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !state.hasAccess { AccessBanner() }

            HStack {
                Toggle(isOn: $state.config.enabled) {
                    Text("TurboKey is active").font(.headline)
                }
                .toggleStyle(.switch)
                Spacer()
                Text("Toggle anywhere: ⌃⌥⌘M")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Picker("Profile:", selection: $state.config.activeProfileID) {
                    ForEach(state.config.profiles) { Text($0.name).tag($0.id) }
                }
                .frame(maxWidth: 240)
                TextField("Profile name", text: $state.config.profiles[state.activeProfileIndex].name)
                    .frame(width: 170)
                Button { state.addProfile() } label: { Image(systemName: "plus") }
                    .help("New profile")
                Button { state.deleteActiveProfile() } label: { Image(systemName: "trash") }
                    .help("Delete this profile")
                    .disabled(state.config.profiles.count < 2)
                Spacer()
            }

            Divider()

            HStack(spacing: 12) {
                Text("On").frame(width: 32, alignment: .leading)
                Text("Key / click").frame(width: 140, alignment: .leading)
                Text("Mode").frame(width: 200, alignment: .leading)
                Text("Count").frame(width: 100, alignment: .leading)
                Text("Delay between presses").frame(maxWidth: .infinity, alignment: .leading)
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
                Label("Add key or mouse click", systemImage: "plus.circle.fill")
            }

            Text("**Multiply:** one press becomes as many presses as «Count». **Hold to spam:** presses again and again while you hold it down. Combinations with ⌘, ⌃ or ⌥ are never multiplied.")
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
                Text("TurboKey needs access").bold()
                Text("System Settings → Privacy & Security → Accessibility → turn on TurboKey.")
                    .font(.callout)
                Text("Already turned on (e.g. after an update)? Remove it with «–» and add it again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings") { state.openAccessibilitySettings() }
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
                    Text("while held").foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, alignment: .leading)

            Slider(value: delayBinding, in: 1...(500.0).squareRoot())
            Text("\(mapping.delayMs) ms")
                .monospacedDigit()
                .frame(width: 52, alignment: .trailing)

            Button(action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Remove")
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .opacity(mapping.enabled ? 1 : 0.55)
    }

    /// Quadratic scale, so small values (1–50 ms) are easy to set precisely.
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
            Button("Keyboard – press a key…") { startRecording() }
            Button("Left mouse click") { trigger = Trigger(kind: .mouseLeft) }
            Button("Right mouse click") { trigger = Trigger(kind: .mouseRight) }
        } label: {
            if recording {
                Text("Press a key…")
            } else if let trigger {
                Label(trigger.displayName, systemImage: trigger.symbolName)
            } else {
                Text("Choose…")
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        stopRecording()
        recording = true
        state.isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode != 53 { // Esc cancels
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
