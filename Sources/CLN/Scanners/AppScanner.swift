import AppKit
import Foundation

enum AppScanner {
    /// One group per installed app (bundle + leftovers), plus a group of orphaned leftovers first.
    static func scan(progress: (String) -> Void) -> [CleanGroup] {
        let bundles = installedApps()
        var groups: [CleanGroup] = []

        progress("Looking for leftovers of removed apps…")
        let orphans = orphanedLeftovers()
        if !orphans.isEmpty {
            groups.append(CleanGroup(title: "Orphaned Leftovers", symbol: "questionmark.folder",
                                     subtitle: "Files from apps that are no longer installed. Check each one before removing it.",
                                     section: Sec.leftovers, items: orphans))
        }

        // Bundle IDs of every installed app, counted: two apps can share one (Photoshop and its beta),
        // and then their settings belong to both.
        var idCount: [String: Int] = [:]
        for app in bundles { if let id = Bundle(url: app)?.bundleIdentifier { idCount[id, default: 0] += 1 } }
        let allIDs = Set(idCount.keys)

        for (i, app) in bundles.enumerated() {
            progress("Measuring \(app.deletingPathExtension().lastPathComponent) (\(i + 1) of \(bundles.count))")
            guard let bundle = Bundle(url: app), let id = bundle.bundleIdentifier, !id.hasPrefix("com.apple.") else { continue }
            let name = app.deletingPathExtension().lastPathComponent
            let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            var items = [CleanItem(url: app, name: name, detail: "Application · \(FS.tilde(app.path))",
                                   size: FS.size(of: app), iconPath: app.path)]
            items += leftovers(bundleID: id, name: name, sharedID: idCount[id, default: 0] > 1,
                               otherIDs: allIDs.subtracting([id]))
            groups.append(CleanGroup(title: name, symbol: "app", subtitle: version.isEmpty ? id : "Version \(version) · \(id)",
                                     iconPath: app.path, section: "Apps", items: items))
        }
        let orphanGroup = groups.filter { $0.section == Sec.leftovers }
        let apps = groups.filter { $0.section != Sec.leftovers }.sorted { $0.totalSize > $1.totalSize }
        return orphanGroup + apps
    }

    static func installedApps() -> [URL] {
        // Also one folder deep, where suites like Adobe's keep their apps.
        let dirs = [URL(fileURLWithPath: "/Applications"), FS.home.appendingPathComponent("Applications")]
        return dirs.flatMap { FS.children($0) }.flatMap { u -> [URL] in
            if u.pathExtension == "app" { return [u] }
            guard (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return [] }
            return FS.children(u).filter { $0.pathExtension == "app" }
        }
    }

    /// Everything an app leaves behind outside its bundle: exact matches by name or bundle ID,
    /// helpers and updaters whose ID starts with the app's ID, crash reports, and system-wide
    /// launch daemons and helper tools. Only items clearly tied to this app are listed.
    /// `sharedID`: another installed app has the same bundle ID, so files named by it are left alone.
    /// `otherIDs`: installed apps whose ID starts with this one's (com.app and com.app.pro) keep theirs.
    static func leftovers(bundleID id: String, name: String, sharedID: Bool = false, otherIDs: Set<String> = []) -> [CleanItem] {
        var items: [CleanItem] = []
        var seen = Set<String>()
        func add(_ u: URL, _ kind: String) {
            guard !seen.contains(u.path), FS.exists(u) else { return }
            seen.insert(u.path)
            items.append(CleanItem(url: u, name: u.lastPathComponent, detail: "\(kind) · \(FS.tilde(u.path))", size: FS.size(of: u)))
        }
        func matchesID(_ file: String) -> Bool {
            var f = file
            for ext in [".plist", ".savedState", ".binarycookies"] where f.hasSuffix(ext) { f = String(f.dropLast(ext.count)) }
            guard !sharedID, f == id || f.hasPrefix(id + ".") else { return false }
            return !otherIDs.contains { $0.count > id.count && (f == $0 || f.hasPrefix($0 + ".")) }
        }

        // Named after the app
        for (rel, kind) in [("Application Support/\(name)", "App data"), ("Caches/\(name)", "Cache"), ("Logs/\(name)", "Logs")] {
            add(FS.lib(rel), kind)
        }
        // Named after the bundle ID, or a helper / updater of it (com.app.id.helper, com.app.id.ShipIt)
        let byID: [(String, String)] = [
            ("Application Support", "App data"), ("Caches", "Cache"), ("Preferences", "Preferences"),
            ("Preferences/ByHost", "Preferences"), ("Containers", "Sandbox container"),
            ("Saved Application State", "Saved window state"), ("Logs", "Logs"), ("HTTPStorages", "Web storage"),
            ("WebKit", "Web data"), ("Cookies", "Cookies"), ("Application Scripts", "Scripts"),
            ("LaunchAgents", "Login item"), ("Application Support/CrashReporter", "Crash reports"),
        ]
        for (dir, kind) in byID {
            for u in FS.children(FS.lib(dir)) where matchesID(u.lastPathComponent) { add(u, kind) }
        }
        // Shared app-group folders are prefixed with the developer's team ID (TEAMID.com.app.id)
        for u in FS.children(FS.lib("Group Containers")) where !sharedID && (u.lastPathComponent.hasSuffix("." + id) || u.lastPathComponent == id) {
            add(u, "Shared data")
        }
        // Crash reports are named after the app (Name_2026-11-19-101500_Mac.ips)
        for u in FS.children(FS.lib("Logs/DiagnosticReports")) where u.lastPathComponent.hasPrefix(name + "_") || u.lastPathComponent.hasPrefix(name + "-") {
            add(u, "Crash report")
        }
        // System-wide parts installed with an administrator password
        let system: [(String, String)] = [
            ("/Library/LaunchAgents", "Login item for all users"), ("/Library/LaunchDaemons", "Background service"),
            ("/Library/PrivilegedHelperTools", "Helper tool"), ("/Library/Preferences", "Preferences for all users"),
            ("/Library/Caches", "Cache for all users"),
        ]
        for (dir, kind) in system {
            for u in FS.children(URL(fileURLWithPath: dir)) where matchesID(u.lastPathComponent) { add(u, kind) }
        }
        add(URL(fileURLWithPath: "/Library/Application Support/\(name)"), "App data for all users")
        if !sharedID { add(URL(fileURLWithPath: "/Library/Application Support/\(id)"), "App data for all users") }
        return items
    }

    /// Reverse-DNS named leftovers whose app can't be found by Launch Services and whose vendor
    /// has no installed app. Conservative on purpose: nothing here is preselected.
    static func orphanedLeftovers() -> [CleanItem] {
        let vendors = Set(installedApps().compactMap { Bundle(url: $0)?.bundleIdentifier }.map(vendor))
        let places = ["Containers", "Saved Application State", "Preferences", "Application Support", "Caches", "HTTPStorages"]
        var out: [CleanItem] = []
        for place in places {
            for u in FS.children(FS.lib(place)) {
                var id = u.lastPathComponent
                if id.hasPrefix(".") { continue }
                for ext in [".savedState", ".plist", ".binarycookies"] where id.hasSuffix(ext) { id = String(id.dropLast(ext.count)) }
                let parts = id.split(separator: ".")
                guard parts.count >= 3, parts.allSatisfy({ !$0.isEmpty && !$0.contains(" ") }),
                      !id.hasPrefix("com.apple."), !id.hasPrefix("group."), !id.contains("GlobalPreferences"),
                      !vendors.contains(vendor(id)),
                      NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) == nil else { continue }
                let size = FS.size(of: u)
                guard size > 0 else { continue }
                out.append(CleanItem(url: u, name: id, detail: "\(place) · \(FS.tilde(u.path))", size: size))
            }
        }
        return out.sorted { $0.size > $1.size }
    }

    private static func vendor(_ id: String) -> String {
        id.split(separator: ".").prefix(2).joined(separator: ".").lowercased()
    }
}
