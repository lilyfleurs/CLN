import AppKit
import Foundation

/// File-system helpers. Everything CLN removes goes through `trash`, which only
/// ever moves items to the Trash and refuses anything outside safe locations.
enum FS {
    static let fm = FileManager.default
    static var home: URL { fm.homeDirectoryForCurrentUser }

    static func lib(_ path: String) -> URL { home.appendingPathComponent("Library/\(path)") }

    static let sizeKeys: Set<URLResourceKey> = [
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isDirectoryKey,
        .isSymbolicLinkKey, .isRegularFileKey,
    ]

    /// Allocated size on disk of a file or a whole directory tree.
    static func size(of url: URL) -> Int64 {
        guard let v = try? url.resourceValues(forKeys: sizeKeys) else { return 0 }
        if v.isSymbolicLink == true { return 0 }
        if v.isDirectory != true {
            let s = Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
            ScanTicker.shared.saw(url, size: s)
            return s
        }
        var total: Int64 = 0
        guard let e = fm.enumerator(at: url, includingPropertiesForKeys: Array(sizeKeys),
                                    options: [], errorHandler: { _, _ in true }) else { return 0 }
        for case let f as URL in e {
            if let r = try? f.resourceValues(forKeys: sizeKeys), r.isRegularFile == true {
                let s = Int64(r.totalFileAllocatedSize ?? r.fileAllocatedSize ?? 0)
                total += s
                ScanTicker.shared.saw(f, size: s)
            }
        }
        return total
    }

    static func children(_ url: URL) -> [URL] {
        (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])) ?? []
    }

    static func exists(_ url: URL) -> Bool { fm.fileExists(atPath: url.path) }

    /// Without Full Disk Access macOS hides the Trash and Mail's folders from CLN.
    static var hasFullDiskAccess: Bool {
        (try? fm.contentsOfDirectory(atPath: home.appendingPathComponent(".Trash").path)) != nil
    }

    static func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }

    static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func tilde(_ path: String) -> String {
        path.hasPrefix(home.path) ? "~" + path.dropFirst(home.path.count) : path
    }

    static func relative(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        f.locale = Lang.current.locale
        return f.localizedString(for: date, relativeTo: Date())
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Safety

    /// Folders that must never be removed themselves, even though their contents may be.
    private static var protectedPaths: Set<String> {
        let h = home.path
        let names = ["", "/Library", "/Desktop", "/Documents", "/Downloads", "/Pictures", "/Movies",
                     "/Music", "/Applications", "/Public", "/Library/Caches", "/Library/Logs",
                     "/Library/Application Support", "/Library/Preferences", "/Library/Containers",
                     "/Library/Group Containers", "/Library/LaunchAgents", "/Library/Mobile Documents",
                     "/Library/CloudStorage", "/.Trash"]
        return Set(names.map { h + $0 } + ["/Applications"])
    }

    /// Folders that are never touched, nor anything inside them: passwords and SSH keys.
    private static var protectedTrees: [String] {
        [home.path + "/Library/Keychains", home.path + "/.ssh"]
    }

    /// `allowSystem`: also accept app leftovers in the system folders below. Only the uninstaller
    /// passes it, for items it matched to one app; everywhere else those folders stay off limits.
    static func isSafeToTrash(_ url: URL, allowSystem: Bool = false) -> Bool {
        let p = url.standardizedFileURL.resolvingSymlinksInPath().path
        if protectedPaths.contains(p) { return false }
        if protectedTrees.contains(where: { p == $0 || p.hasPrefix($0 + "/") }) { return false }
        if systemLeftoverDirs.contains(where: { p.hasPrefix($0 + "/") }) {
            return allowSystem && !url.lastPathComponent.hasPrefix("com.apple.")
        }
        return p.hasPrefix(home.path + "/") || p.hasPrefix("/Applications/")
    }

    /// System folders where apps install parts for all users. Only items the uninstaller matched to
    /// one app by its name or bundle ID are listed from here, and Finder asks for the password.
    static let systemLeftoverDirs = ["/Library/LaunchAgents", "/Library/LaunchDaemons", "/Library/PrivilegedHelperTools",
                                     "/Library/Preferences", "/Library/Caches", "/Library/Application Support"]

    /// Moves items to the Trash. Returns what was freed and the URLs actually moved.
    static func trash(_ items: [CleanItem], allowSystem: Bool = false) -> (CleanResult, Set<URL>) {
        var result = CleanResult()
        var moved = Set<URL>()
        for item in items {
            var ok = true
            var denied = false
            for url in item.allURLs where exists(url) {
                if !trashOne(url, name: item.name, allowSystem: allowSystem, into: &result, denied: &denied) { ok = false }
            }
            if denied { result.blocked.append(item) }
            guard ok else { continue }
            result.freed += item.size
            result.count += 1
            moved.insert(item.url)
        }
        return (result, moved)
    }

    private static func trashOne(_ url: URL, name: String, allowSystem: Bool, into result: inout CleanResult, denied: inout Bool) -> Bool {
        guard isSafeToTrash(url, allowSystem: allowSystem) else {
            result.failures.append("\(name): \(tilde(url.path)) is outside the folders CLN is allowed to clean")
            return false
        }
        do {
            try fm.trashItem(at: url, resultingItemURL: nil)
            return true
        } catch {
            // Finder can remove what CLN can't on its own: apps owned by the system (it asks for a
            // password) and other apps' protected data folders.
            if finderTrash(url) { return true }
            if isPermissionError(error) {
                denied = true
                result.failures.append("\(name): macOS protects this folder. Give CLN Full Disk Access, then try again.")
            } else {
                result.failures.append("\(name): \(error.localizedDescription)")
            }
            return false
        }
    }

    private static func isPermissionError(_ error: Error) -> Bool {
        let e = error as NSError
        if e.domain == NSCocoaErrorDomain, [CocoaError.fileWriteNoPermission.rawValue, CocoaError.fileReadNoPermission.rawValue].contains(e.code) { return true }
        let posix = (e.userInfo[NSUnderlyingErrorKey] as? NSError) ?? e
        return posix.domain == NSPOSIXErrorDomain && [Int(EPERM), Int(EACCES)].contains(posix.code)
    }

    /// Permanently empties the Trash through Finder. Only called after an explicit confirmation.
    static func emptyTrash() -> Bool {
        Shell.run("/usr/bin/osascript", ["-e", "tell application \"Finder\" to empty trash"]).status == 0
    }

    private static func finderTrash(_ url: URL) -> Bool {
        let escaped = url.path.replacingOccurrences(of: "\"", with: "\\\"")
        return Shell.run("/usr/bin/osascript",
                         ["-e", "tell application \"Finder\" to delete POSIX file \"\(escaped)\""]).status == 0
    }
}

enum Shell {
    @discardableResult
    static func run(_ tool: String, _ args: [String]) -> (status: Int32, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    /// Runs a shell command with admin rights; macOS shows its own password prompt.
    static func runAsAdmin(_ command: String) -> (status: Int32, output: String) {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return run("/usr/bin/osascript", ["-e", "do shell script \"\(escaped)\" with administrator privileges"])
    }
}

/// A flag a long scan checks so the user can stop it.
final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _cancelled = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return _cancelled }
    func cancel() { lock.lock(); _cancelled = true; lock.unlock() }
}

/// Live view of what a scan is looking at, read by the scanning screen a few times a second.
final class ScanTicker: @unchecked Sendable {
    static let shared = ScanTicker()
    private let lock = NSLock()
    private var path = ""
    private var files = 0
    private var bytes: Int64 = 0

    func reset() {
        lock.lock(); path = ""; files = 0; bytes = 0; lock.unlock()
    }

    func saw(_ url: URL, size: Int64) {
        lock.lock()
        files += 1
        bytes += size
        if files % 7 == 0 { path = url.path }
        lock.unlock()
    }

    var snapshot: (path: String, files: Int, bytes: Int64) {
        lock.lock(); defer { lock.unlock() }
        return (path, files, bytes)
    }
}
