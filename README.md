# TurboKey ⚡

**A free, open-source key multiplier and auto clicker for macOS** – a lightweight AutoHotkey alternative that lives in your menu bar.

Press **W** once and TurboKey presses it 10 times for you. Or hold a key (or mouse button) and it fires again and again – a turbo button for any app.

## Features

- **Multiply** – one press becomes 2–1000 presses.
- **Hold to spam** – repeats for as long as you hold the key or button down.
- **Keys and mouse clicks** – left and right mouse clicks work too (auto clicker).
- **Adjustable speed** – 1–500 ms delay between presses.
- **Profiles** – save different setups and switch between them from the menu bar.
- **⌃⌥⌘M** toggles TurboKey on/off from anywhere.
- **Safe by default** – combinations with ⌘, ⌃ or ⌥ are never multiplied (so ⌘W won't close ten windows).
- **Built-in updates** – *Check for Updates…* installs new versions with one click.

Requires macOS 15 or later. Runs natively on both Apple Silicon and Intel Macs.

## Installation

1. Download **TurboKey.zip** from the [latest release](https://github.com/olaimalm/TurboKey/releases/latest).
2. Unzip it and drag **TurboKey.app** into your **Applications** folder.
3. Open the app. The first time, macOS will say it can't verify the developer (the app is not notarized by Apple).
   Go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
   Or run this in Terminal:
   ```bash
   xattr -dr com.apple.quarantine /Applications/TurboKey.app
   ```
4. Grant access in **System Settings → Privacy & Security → Accessibility** and turn on TurboKey.
   Without this, the app can't see or send key presses.
5. Click the ⚡ icon in the menu bar → **Active**.

> After an update, macOS may "forget" the access even though the switch is still on.
> Remove TurboKey from the list with **–** and add it again.

## Usage

Click ⚡ → **Settings…**. For each row you choose:

| Field | Meaning |
| --- | --- |
| Key / click | Click and press a key, or choose left/right mouse click |
| Mode | *Multiply* or *Hold to spam* |
| Count | Total presses per real press (including your own) |
| Delay | Time between each extra press |

⚠️ Many online games have anti-cheat systems that can detect macros. Use at your own risk.

## Development

Requires Xcode (or the Command Line Tools with Swift 6).

```bash
./build.sh            # build for this Mac → build/TurboKey.app
./build.sh --install  # build, install to /Applications and launch
./build.sh --release  # universal build + build/TurboKey.zip
```

The code lives in `Sources/`:

- `InputEngine.swift` – captures and sends key presses/clicks (CGEventTap)
- `AppState.swift` – settings, profiles and permissions
- `Views.swift` – menu bar and settings window (SwiftUI)
- `Updater.swift` – checks for and installs new versions from GitHub Releases

### Releasing a new version

```bash
git tag v1.2.0
git push origin v1.2.0
```

GitHub Actions builds the app and publishes a new release with `TurboKey.zip`.
Everyone who has the app is notified the next time they launch it (or via *Check for Updates…*).

## License

MIT – see [LICENSE](LICENSE).
