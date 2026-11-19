import AppKit
import Foundation

/// A newer CLN published on GitHub Releases.
struct CLNRelease {
    let version: String
    let page: URL
    /// The CLN zip attached to the release, when there is one.
    let download: URL?
    let notes: String
}

/// Keeps CLN itself up to date from its GitHub Releases: checks at most once a day, and can
/// download the new version, swap it in place of this one and restart.
@MainActor
final class SelfUpdate: ObservableObject {
    static let shared = SelfUpdate()

    @Published var available: CLNRelease?
    @Published var state: State = .idle

    enum State: Equatable { case idle, checking, upToDate, downloading, failed(String) }

    private let lastCheckKey = "cln.selfupdate.lastCheck"

    /// Daily check, quietly; does nothing until `Links.repo` is set.
    func checkIfDue() {
        let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > 86_400 else { return }
        check()
    }

    func check() {
        guard let repo = Links.repo,
              let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
        state = .checking
        Task {
            var req = URLRequest(url: url)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let release: CLNRelease? = await {
                guard let (data, resp) = try? await URLSession.shared.data(for: req),
                      (resp as? HTTPURLResponse)?.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String,
                      let page = (json["html_url"] as? String).flatMap(URL.init(string:)) else { return nil }
                let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                let assets = json["assets"] as? [[String: Any]] ?? []
                let zip = assets.first { ($0["name"] as? String)?.lowercased().hasSuffix(".zip") == true }
                let download = (zip?["browser_download_url"] as? String).flatMap(URL.init(string:))
                return CLNRelease(version: version, page: page, download: download, notes: json["body"] as? String ?? "")
            }()
            UserDefaults.standard.set(Date(), forKey: lastCheckKey)
            if let release, Self.isNewer(release.version, than: AppInfo.version) {
                available = release
                state = .idle
            } else {
                available = nil
                state = release == nil ? .failed(L("Couldn't reach GitHub.")) : .upToDate
            }
        }
    }

    /// Downloads the new version, checks it is CLN and newer, swaps it in and restarts.
    /// Falls back to opening the release page when it can't replace the app where it is.
    func install() {
        guard let release = available else { return }
        let current = Bundle.main.bundleURL
        guard let download = release.download, current.pathExtension == "app",
              FileManager.default.isWritableFile(atPath: current.deletingLastPathComponent().path) else {
            NSWorkspace.shared.open(release.page)
            return
        }
        state = .downloading
        Task {
            let result = await Self.downloadAndUnpack(download, expecting: release.version)
            switch result {
            case .success(let newApp): Self.swapAndRelaunch(newApp, replacing: current)
            case .failure(let message): state = .failed(message)
            }
        }
    }

    private enum Unpacked { case success(URL), failure(String) }

    nonisolated private static func downloadAndUnpack(_ url: URL, expecting version: String) async -> Unpacked {
        guard let (file, resp) = try? await URLSession.shared.download(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return .failure(L("The download didn't finish.")) }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("CLN-update-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard Shell.run("/usr/bin/ditto", ["-x", "-k", file.path, dir.path]).status == 0 else {
            return .failure(L("The download couldn't be unpacked."))
        }
        let app = FS.children(dir).first { $0.pathExtension == "app" }
        // Only ever swap in CLN itself, and only the version the release promised.
        guard let app, let info = Bundle(url: app)?.infoDictionary,
              info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              info["CFBundleShortVersionString"] as? String == version else {
            return .failure(L("The download isn't the expected CLN version."))
        }
        return .success(app)
    }

    /// Waits for this copy to quit, moves the old app to the Trash, puts the new one in its
    /// place and opens it.
    private static func swapAndRelaunch(_ newApp: URL, replacing current: URL) {
        func q(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let trash = FS.home.appendingPathComponent(".Trash/CLN \(AppInfo.version).app").path
        let script = """
        while kill -0 \(getpid()) 2>/dev/null; do sleep 0.2; done
        mv -f \(q(current.path)) \(q(trash)) && mv \(q(newApp.path)) \(q(current.path)) && open \(q(current.path))
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script]
        try? p.run()
        NSApp.terminate(nil)
    }

    /// Compares dotted version numbers: 1.10.0 is newer than 1.9.2.
    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
