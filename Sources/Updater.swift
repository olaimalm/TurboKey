import AppKit

/// Sjekker GitHub Releases for nye versjoner og kan installere dem i stedet for den gamle appen.
enum Updater {
    static let repo = "olaimalm/TurboTast"
    static let assetName = "TurboTast.zip"

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

    /// `silent`: vis bare noe hvis det finnes en ny versjon (brukes ved oppstart).
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
            if !silent { alert("Kunne ikke sjekke etter oppdateringer", "Sjekk at du er koblet til internett.") }
            return
        }
        guard release.version.compare(currentVersion, options: .numeric) == .orderedDescending else {
            if !silent { alert("Du har siste versjon", "TurboTast \(currentVersion) er den nyeste.") }
            return
        }

        let asset = release.assets.first { $0.name == assetName }
        let answer = alert(
            "TurboTast \(release.version) er klar",
            "Du har \(currentVersion). Etter oppdateringen må du kanskje gi TurboTast tilgang under Tilgjengelighet på nytt.",
            buttons: asset == nil ? ["Åpne nedlastingssiden", "Senere"] : ["Installer og start på nytt", "Se hva som er nytt", "Senere"]
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
                    let answer = alert("Oppdateringen feilet", error.localizedDescription,
                                       buttons: ["Last ned manuelt", "Avbryt"])
                    if answer == .alertFirstButtonReturn { NSWorkspace.shared.open(fallback) }
                }
            }
        }.resume()
    }

    private static func replaceApp(withZip zip: URL) throws {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("TurboTast-update-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-x", "-k", zip.path, work.path]
        try unzip.run()
        unzip.waitUntilExit()

        let newApp = work.appendingPathComponent("TurboTast.app")
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
