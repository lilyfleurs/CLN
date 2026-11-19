import Foundation

struct AppUpdate: Identifiable {
    let id = UUID()
    let name: String
    let appURL: URL
    let current: String
    let latest: String
    let fromAppStore: Bool
    /// App Store page for App Store apps; nil for apps that update themselves.
    let link: URL?
}

/// Checks installed apps for newer versions. Runs only when the user asks.
/// App Store apps are looked up with Apple's public lookup service; other apps through the
/// Sparkle update feed they declare in their Info.plist. Only bundle identifiers are sent.
enum UpdateChecker {
    private static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 12
        c.httpCookieStorage = nil
        return URLSession(configuration: c)
    }()

    static func check() async -> (updates: [AppUpdate], checked: Int) {
        let apps = AppScanner.installedApps().compactMap { url -> (URL, [String: Any])? in
            guard let info = Bundle(url: url)?.infoDictionary,
                  let id = info["CFBundleIdentifier"] as? String, !id.hasPrefix("com.apple.") else { return nil }
            return (url, info)
        }
        return await withTaskGroup(of: (Bool, AppUpdate?).self) { group in
            for (url, info) in apps {
                group.addTask { await checkOne(url, info) }
            }
            var out: [AppUpdate] = []
            var checked = 0
            for await (ok, update) in group {
                if ok { checked += 1 }
                if let update { out.append(update) }
            }
            return (out.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }, checked)
        }
    }

    /// Returns whether the app could be checked, and the update if one exists.
    private static func checkOne(_ url: URL, _ info: [String: Any]) async -> (Bool, AppUpdate?) {
        let name = url.deletingPathExtension().lastPathComponent
        let short = info["CFBundleShortVersionString"] as? String ?? ""
        let build = info["CFBundleVersion"] as? String ?? ""

        if FS.exists(url.appendingPathComponent("Contents/_MASReceipt")), let id = info["CFBundleIdentifier"] as? String {
            var c = URLComponents(string: "https://itunes.apple.com/lookup")!
            c.queryItems = [URLQueryItem(name: "bundleId", value: id),
                            URLQueryItem(name: "country", value: Locale.current.region?.identifier.lowercased() ?? "us")]
            guard let (data, _) = try? await session.data(from: c.url!),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = (json["results"] as? [[String: Any]])?.first,
                  let latest = result["version"] as? String else { return (false, nil) }
            guard isNewer(latest, than: short) else { return (true, nil) }
            let page = (result["trackViewUrl"] as? String)
                .flatMap { URL(string: $0.replacingOccurrences(of: "https://", with: "macappstore://")) }
            return (true, AppUpdate(name: name, appURL: url, current: short, latest: latest, fromAppStore: true, link: page))
        }

        if let feed = (info["SUFeedURL"] as? String).flatMap(URL.init(string:)), feed.scheme == "https" {
            guard let (data, _) = try? await session.data(from: feed),
                  let xml = String(data: data, encoding: .utf8) else { return (false, nil) }
            if let latest = values(in: xml, for: "shortVersionString").max(by: { isNewer($1, than: $0) }) {
                guard isNewer(latest, than: short) else { return (true, nil) }
                return (true, AppUpdate(name: name, appURL: url, current: short, latest: latest, fromAppStore: false, link: nil))
            }
            // Some feeds only list build numbers
            if let latestBuild = values(in: xml, for: "version").max(by: { isNewer($1, than: $0) }) {
                guard isNewer(latestBuild, than: build) else { return (true, nil) }
                return (true, AppUpdate(name: name, appURL: url, current: short, latest: latestBuild, fromAppStore: false, link: nil))
            }
        }
        return (false, nil)
    }

    /// Values of sparkle:<key>, written either as an attribute or as an element.
    private static func values(in xml: String, for key: String) -> [String] {
        let patterns = ["sparkle:\(key)=\"([^\"]+)\"", "<sparkle:\(key)>([^<]+)</sparkle:\(key)>"]
        return patterns.flatMap { p -> [String] in
            guard let re = try? NSRegularExpression(pattern: p) else { return [] }
            return re.matches(in: xml, range: NSRange(xml.startIndex..., in: xml)).compactMap {
                Range($0.range(at: 1), in: xml).map { String(xml[$0]).trimmingCharacters(in: .whitespaces) }
            }
        }
    }

    /// Compares dotted version numbers, e.g. "2.10.1" > "2.9".
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        let pb = b.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard !pa.isEmpty, !pb.isEmpty else { return false }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
