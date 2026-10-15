import AppKit

/// Checks GitHub Releases for new versions and can install them in place of the current app.
enum Updater {
    static let repo = "olaimalm/TurboKey"
    static let assetName = "TurboKey.zip"

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
        let tag_name: String
        let html_url: URL
        let assets: [Asset]

        var version: String { tag_name.hasPrefix("v") ? String(tag_name.dropFirst()) : tag_name }
    }

    /// `silent`: only show something if there is a new version (used at launch).
    static func check(silent: Bool) {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let release = data.flatMap { try? JSONDecoder().decode(Release.self, from: $0) }
            DispatchQueue.main.async { present(release, silent: silent) }
        }.resume()
    }

    private static func present(_ release: Release?, silent: Bool) {
        guard let release else {
            if !silent { alert("Couldn’t check for updates", "Make sure you’re connected to the internet.") }
            return
        }
        guard release.version.compare(currentVersion, options: .numeric) == .orderedDescending else {
            if !silent { alert("You’re up to date", "TurboKey \(currentVersion) is the latest version.") }
            return
        }

        let asset = release.assets.first { $0.name == assetName }
        let answer = alert(
            "TurboKey \(release.version) is available",
            "You have \(currentVersion). After updating, you may need to grant TurboKey Accessibility access again.",
            buttons: asset == nil ? ["Open Download Page", "Later"] : ["Install and Relaunch", "What’s New", "Later"]
        )
        switch (answer, asset) {
        case (.alertFirstButtonReturn, let asset?): install(from: asset.browser_download_url, fallback: release.html_url)
        case (.alertFirstButtonReturn, nil), (.alertSecondButtonReturn, .some): NSWorkspace.shared.open(release.html_url)
        default: break
        }
    }

    private static func install(from url: URL, fallback: URL) {
        URLSession.shared.downloadTask(with: url) { file, _, error in
            DispatchQueue.main.async {
                do {
                    guard let file else { throw error ?? URLError(.badServerResponse) }
                    try replaceApp(withZip: file)
                } catch {
                    let answer = alert("Update failed", error.localizedDescription,
                                       buttons: ["Download Manually", "Cancel"])
                    if answer == .alertFirstButtonReturn { NSWorkspace.shared.open(fallback) }
                }
            }
        }.resume()
    }

    private static func replaceApp(withZip zip: URL) throws {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("TurboKey-update-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-x", "-k", zip.path, work.path]
        try unzip.run()
        unzip.waitUntilExit()

        let newApp = work.appendingPathComponent("TurboKey.app")
        guard unzip.terminationStatus == 0, fm.fileExists(atPath: newApp.path) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let current = Bundle.main.bundleURL
        _ = try fm.replaceItemAt(current, withItemAt: newApp)

        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", current.path]
        try relaunch.run()
        NSApp.terminate(nil)
    }

    @discardableResult
    private static func alert(_ title: String, _ text: String, buttons: [String] = ["OK"]) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        buttons.forEach { alert.addButton(withTitle: $0) }
        return alert.runModal()
    }
}
