import Foundation

struct LaunchItem: Identifiable {
    let id = UUID()
    let url: URL
    let label: String
    let program: String
    let programExists: Bool
    let isUser: Bool
    let isDaemon: Bool
    /// Loaded in launchd right now (with a process if `pid` is set).
    var loaded = false
    var pid: Int?
    /// Turned off with `launchctl disable`, so it won't start again.
    var disabled = false
    /// The app it belongs to, when its program lives inside an app bundle.
    var owner: String? {
        guard let r = program.range(of: ".app/") else { return nil }
        return URL(fileURLWithPath: String(program[..<r.lowerBound]) + ".app").deletingPathExtension().lastPathComponent
    }
    /// launchd domain it runs in: system-wide daemons, otherwise your login session.
    var domain: String { isDaemon ? "system" : "gui/\(getuid())" }
}

enum LaunchScanner {
    static func scan() -> [LaunchItem] {
        let dirs: [(URL, Bool, Bool)] = [
            (FS.lib("LaunchAgents"), true, false),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), false, false),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), false, true),
        ]
        let user = services(Shell.run("/bin/launchctl", ["print", "gui/\(getuid())"]).output)
        let system = services(Shell.run("/bin/launchctl", ["print", "system"]).output)
        let off = disabled(Shell.run("/bin/launchctl", ["print-disabled", "gui/\(getuid())"]).output)
            .union(disabled(Shell.run("/bin/launchctl", ["print-disabled", "system"]).output))
        return dirs.flatMap { dir, isUser, isDaemon in
            FS.children(dir).filter { $0.pathExtension == "plist" }.compactMap { parse($0, isUser: isUser, isDaemon: isDaemon) }
        }.map { item in
            var i = item
            let state = (i.isDaemon ? system : user)[i.label]
            i.loaded = state != nil
            i.pid = state ?? nil
            i.disabled = off.contains(i.label)
            return i
        }
    }

    /// Labels in a `launchctl print` services block, with their process ID when running.
    private static func services(_ text: String) -> [String: Int?] {
        guard let start = text.range(of: "services = {") else { return [:] }
        var out: [String: Int?] = [:]
        for line in text[start.upperBound...].split(separator: "\n") {
            let parts = line.split(whereSeparator: \.isWhitespace)
            if parts.first == "}" { break }
            guard parts.count >= 3 else { continue }
            let pid = Int(parts[0]).flatMap { $0 > 0 ? $0 : nil }
            out[String(parts[2])] = pid
        }
        return out
    }

    /// Labels marked "=> disabled" in `launchctl print-disabled`.
    private static func disabled(_ text: String) -> Set<String> {
        Set(text.split(separator: "\n").compactMap { line in
            guard line.contains("=> disabled"), let q1 = line.firstIndex(of: "\""),
                  let q2 = line[line.index(after: q1)...].firstIndex(of: "\"") else { return nil }
            return String(line[line.index(after: q1)..<q2])
        })
    }

    private static func parse(_ url: URL, isUser: Bool, isDaemon: Bool) -> LaunchItem? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        let label = plist["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
        let program = plist["Program"] as? String ?? (plist["ProgramArguments"] as? [String])?.first ?? ""
        // Bare command names (no slash) are resolved through PATH, so they count as present.
        let exists = program.isEmpty || !program.hasPrefix("/") || FS.fm.fileExists(atPath: program)
        return LaunchItem(url: url, label: label, program: program, programExists: exists, isUser: isUser, isDaemon: isDaemon)
    }

    /// Broken user agents as cleanable items (their program is gone).
    static func brokenItems() -> [CleanItem] {
        scan().filter { $0.isUser && !$0.programExists }.map {
            CleanItem(url: $0.url, name: $0.label, detail: "Points to missing \(FS.tilde($0.program))",
                      size: FS.size(of: $0.url), selected: true)
        }
    }

    /// Stops a user agent now; trashing its plist keeps it from starting at the next login.
    static func unload(_ url: URL) {
        Shell.run("/bin/launchctl", ["bootout", "gui/\(getuid())", url.path])
    }
}

/// Turning launch items off and on, and removing them. System-wide items ask for the
/// administrator password (the prompt comes from macOS).
enum LaunchControl {
    private static func q(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    /// Stops it now and keeps it from starting again. Reversible with `turnOn`.
    static func turnOff(_ i: LaunchItem) -> Bool {
        let target = q("\(i.domain)/\(i.label)")
        let cmd = "/bin/launchctl bootout \(target) 2>/dev/null; /bin/launchctl disable \(target)"
        return i.isDaemon ? Shell.runAsAdmin(cmd).status == 0 : Shell.run("/bin/sh", ["-c", cmd]).status == 0
    }

    static func turnOn(_ i: LaunchItem) -> Bool {
        let cmd = "/bin/launchctl enable \(q("\(i.domain)/\(i.label)")); /bin/launchctl bootstrap \(q(i.domain)) \(q(i.url.path)) 2>/dev/null; true"
        return i.isDaemon ? Shell.runAsAdmin(cmd).status == 0 : Shell.run("/bin/sh", ["-c", cmd]).status == 0
    }

    /// Turns it off and moves its file to your Trash, so it can be put back.
    static func remove(_ i: LaunchItem) -> Bool {
        let target = q("\(i.domain)/\(i.label)")
        let stop = "/bin/launchctl bootout \(target) 2>/dev/null; /bin/launchctl disable \(target) 2>/dev/null"
        if i.isUser {
            Shell.run("/bin/sh", ["-c", stop])
            return !FS.trash([CleanItem(url: i.url, name: i.label, detail: "", size: FS.size(of: i.url))]).1.isEmpty
        }
        // One password prompt for stopping it and moving its file out of /Library.
        let trash = FS.home.appendingPathComponent(".Trash").appendingPathComponent(i.url.lastPathComponent).path
        return Shell.runAsAdmin("\(stop); /bin/mv -f \(q(i.url.path)) \(q(trash))").status == 0
    }
}

struct MaintenanceTask: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let needsAdmin: Bool
    let command: String

    /// Computed so titles follow the current language.
    static var all: [MaintenanceTask] { [
        MaintenanceTask(id: "dns", title: L("Flush DNS Cache"), detail: L("Fixes websites that won't load after network changes."),
                        symbol: "network", needsAdmin: true,
                        command: "dscacheutil -flushcache; killall -HUP mDNSResponder"),
        MaintenanceTask(id: "ram", title: L("Free Up RAM"), detail: L("Clears inactive memory so busy apps get room."),
                        symbol: "memorychip", needsAdmin: true, command: "/usr/sbin/purge"),
        MaintenanceTask(id: "ql", title: L("Reset Quick Look"), detail: L("Fixes blank or outdated file previews and thumbnails."),
                        symbol: "eye", needsAdmin: false, command: "/usr/bin/qlmanage -r cache; /usr/bin/qlmanage -r"),
        MaintenanceTask(id: "spotlight", title: L("Reindex Spotlight"), detail: L("Rebuilds search when results are missing. Takes a while to finish."),
                        symbol: "magnifyingglass", needsAdmin: true, command: "/usr/bin/mdutil -E /"),
        MaintenanceTask(id: "ls", title: L("Rebuild Launch Services"), detail: L("Fixes duplicate entries in the \"Open With\" menu."),
                        symbol: "arrow.triangle.2.circlepath", needsAdmin: false,
                        command: "LS=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister; $LS -gc && $LS -r -f -all local,system,user"),
    ] }

    func run() -> Bool {
        needsAdmin ? Shell.runAsAdmin(command).status == 0 : Shell.run("/bin/sh", ["-c", command]).status == 0
    }
}
