import AppKit
import Foundation

enum JunkScanner {
    /// Scans system junk, AI clutter, Mail attachments and the Trash.
    static func scan(progress: (String) -> Void) -> [CleanGroup] {
        var groups: [CleanGroup] = []
        let aiCaches = Set(AITools.tools.flatMap(\.paths).filter { $0.hasPrefix("Library/Caches/") }
            .map { String($0.dropFirst("Library/Caches/".count)) })

        progress("Looking at app caches…")
        groups.append(CleanGroup(title: "User Cache Files", symbol: "archivebox",
                                 subtitle: "Temporary data apps rebuild automatically. Apple's own caches are listed but not selected.",
                                 section: Sec.junk,
                                 items: folderItems(FS.lib("Caches"), exclude: aiCaches) { !$0.hasPrefix("com.apple.") }))

        progress("Looking at log files…")
        groups.append(CleanGroup(title: "User Logs", symbol: "doc.text",
                                 subtitle: "Diagnostic logs written by apps.", section: Sec.junk,
                                 items: folderItems(FS.lib("Logs"), exclude: ["Claude"]) { _ in true }))

        progress("Looking for developer leftovers…")
        var dev = folderItems(FS.lib("Developer/Xcode/DerivedData"), detailPrefix: "Xcode build data") { _ in true }
        dev += folderItems(FS.lib("Developer/Xcode/iOS DeviceSupport"), detailPrefix: "iOS device support") { _ in false }
        dev += folderItems(FS.lib("Developer/CoreSimulator/Caches"), detailPrefix: "Simulator cache") { _ in true }
        groups.append(CleanGroup(title: "Developer Junk", symbol: "hammer",
                                 subtitle: "Xcode build products and simulator caches.", section: Sec.junk, items: dev))

        progress("Looking at package manager caches…")
        var pkg: [CleanItem] = []
        for (path, label) in [(".npm/_cacache", "npm cache"), (".gradle/caches", "Gradle cache"),
                              (".cargo/registry/cache", "Cargo cache"), (".pnpm-store", "pnpm store"),
                              (".bun/install/cache", "Bun cache")] {
            if let item = item(FS.home.appendingPathComponent(path), name: label, selected: false) { pkg.append(item) }
        }
        pkg += folderItems(FS.home.appendingPathComponent(".cache"), exclude: ["huggingface", "lm-studio"]) { _ in false }
        groups.append(CleanGroup(title: "Package Caches", symbol: "shippingbox",
                                 subtitle: "Downloaded packages that tools fetch again when needed.", section: Sec.junk,
                                 items: pkg.sorted { $0.size > $1.size }))

        progress("Looking at AI tools…")
        groups.append(AITools.scan())

        progress("Looking at Mail attachments…")
        groups.append(CleanGroup(title: "Mail Downloads", symbol: "envelope",
                                 subtitle: "Copies of attachments you opened. The originals stay in your mailbox.",
                                 section: Sec.mail,
                                 items: folderItems(FS.lib("Containers/com.apple.mail/Data/Library/Mail Downloads")) { _ in true }))

        progress("Looking in the Trash…")
        groups.append(CleanGroup(title: "Trash", symbol: "trash",
                                 subtitle: "Emptying the Trash deletes these files permanently.", section: Sec.trash,
                                 items: folderItems(FS.home.appendingPathComponent(".Trash")) { _ in true }))

        return groups.filter { !$0.items.isEmpty }
    }

    static func folderItems(_ base: URL, exclude: Set<String> = [], detailPrefix: String? = nil,
                            preselect: (String) -> Bool) -> [CleanItem] {
        FS.children(base)
            .filter { !exclude.contains($0.lastPathComponent) && $0.lastPathComponent != ".DS_Store" }
            .compactMap { u -> CleanItem? in
                let size = FS.size(of: u)
                guard size > 0 else { return nil }
                let (name, icon) = displayName(u)
                let detail = detailPrefix.map { "\($0) · \(FS.tilde(u.path))" } ?? FS.tilde(u.path)
                let date = try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                return CleanItem(url: u, name: name, detail: detail, size: size, date: date,
                                 selected: preselect(u.lastPathComponent), iconPath: icon)
            }
            .sorted { $0.size > $1.size }
    }

    static func item(_ url: URL, name: String, selected: Bool) -> CleanItem? {
        guard FS.exists(url) else { return nil }
        let size = FS.size(of: url)
        guard size > 0 else { return nil }
        return CleanItem(url: url, name: name, detail: FS.tilde(url.path), size: size, selected: selected)
    }

    /// Turns a bundle-ID folder name into the app's name and icon when the app is installed.
    static func displayName(_ url: URL) -> (String, String?) {
        let raw = url.lastPathComponent
        let id = raw.replacingOccurrences(of: ".savedState", with: "").replacingOccurrences(of: ".plist", with: "")
        if id.split(separator: ".").count >= 3,
           let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            return (app.deletingPathExtension().lastPathComponent, app.path)
        }
        return (raw, nil)
    }
}

/// Known locations of caches, logs and downloaded models for AI tools.
enum AITools {
    struct Tool {
        let name: String
        let bundleID: String?
        let paths: [String]
        var note = "Caches and logs. Quit the app before cleaning."
    }

    static let tools: [Tool] = [
        Tool(name: "Claude", bundleID: "com.anthropic.claudefordesktop", paths: [
            "Library/Application Support/Claude/Cache", "Library/Application Support/Claude/Code Cache",
            "Library/Application Support/Claude/GPUCache", "Library/Application Support/Claude/DawnGraphiteCache",
            "Library/Application Support/Claude/DawnWebGPUCache", "Library/Logs/Claude",
            "Library/Caches/com.anthropic.claudefordesktop", "Library/Caches/com.anthropic.claudefordesktop.ShipIt",
        ]),
        Tool(name: "Claude Code", bundleID: nil, paths: [
            ".claude/debug", ".claude/shell-snapshots", ".claude/statsig", "Library/Caches/claude-cli-nodejs",
        ], note: "Debug logs and temporary snapshots. Close running sessions first."),
        Tool(name: "ChatGPT", bundleID: "com.openai.chat", paths: ["Library/Caches/com.openai.chat"]),
        Tool(name: "Codex", bundleID: "com.openai.codex", paths: [".codex/log", "Library/Caches/com.openai.codex"]),
        Tool(name: "Cursor", bundleID: "com.todesktop.230313mzl4w4u92", paths: [
            "Library/Application Support/Cursor/Cache", "Library/Application Support/Cursor/CachedData",
            "Library/Application Support/Cursor/Code Cache", "Library/Application Support/Cursor/GPUCache",
            "Library/Application Support/Cursor/logs", "Library/Application Support/Cursor/CachedExtensionVSIXs",
            "Library/Caches/com.todesktop.230313mzl4w4u92", "Library/Caches/com.todesktop.230313mzl4w4u92.ShipIt",
        ]),
        Tool(name: "Gemini CLI", bundleID: nil, paths: [".gemini/tmp"]),
        Tool(name: "Ollama models", bundleID: "com.electron.ollama", paths: [".ollama/models"],
             note: "Downloaded models. You'd need to download them again to use them."),
        Tool(name: "LM Studio models", bundleID: "ai.elementlabs.lmstudio", paths: [".lmstudio/models", ".cache/lm-studio/models"],
             note: "Downloaded models. You'd need to download them again to use them."),
        Tool(name: "Hugging Face models", bundleID: nil, paths: [".cache/huggingface/hub"],
             note: "Downloaded models and datasets. They download again on next use."),
    ]

    static func scan() -> CleanGroup {
        let items: [CleanItem] = tools.compactMap { tool in
            let urls = tool.paths.map { FS.home.appendingPathComponent($0) }.filter(FS.exists)
            guard let first = urls.first else { return nil }
            let size = urls.reduce(Int64(0)) { $0 + FS.size(of: $1) }
            guard size > 0 else { return nil }
            let icon = tool.bundleID.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)?.path }
            let where_ = urls.count == 1 ? FS.tilde(first.path) : "\(urls.count) locations"
            return CleanItem(url: first, name: tool.name, detail: "\(tool.note) · \(where_)", size: size,
                             selected: false, others: Array(urls.dropFirst()), iconPath: icon)
        }
        return CleanGroup(title: "AI Junk Files", symbol: "sparkles",
                          subtitle: "Caches, logs and temporary files from AI tools. Nothing here is selected until you choose.",
                          section: Sec.ai, items: items.sorted { $0.size > $1.size })
    }
}
