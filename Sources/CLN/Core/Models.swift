import Foundation
import SwiftUI

struct CleanItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var name: String
    var detail: String
    var size: Int64
    var date: Date? = nil
    var selected: Bool = false
    /// Further paths cleaned together with `url` (e.g. every cache folder of one AI tool).
    var others: [URL] = []
    var iconPath: String? = nil

    var allURLs: [URL] { [url] + others }
}

struct CleanGroup: Identifiable {
    let id = UUID()
    var title: String
    var symbol: String
    var subtitle: String = ""
    var iconPath: String? = nil
    /// Which summary card this group belongs to on screens that show cards.
    var section: String = ""
    var items: [CleanItem]

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    var selectedSize: Int64 { items.filter(\.selected).reduce(0) { $0 + $1.size } }
    var selectedCount: Int { items.filter(\.selected).count }
}

extension Array where Element == CleanGroup {
    var selectedItems: [CleanItem] { flatMap(\.items).filter(\.selected) }
    var totalSize: Int64 { reduce(0) { $0 + $1.totalSize } }

    func removing(_ urls: Set<URL>) -> [CleanGroup] {
        compactMap { g in
            var g = g
            g.items.removeAll { urls.contains($0.url) }
            return g.items.isEmpty ? nil : g
        }
    }
}

struct CleanResult {
    var freed: Int64 = 0
    var count = 0
    var failures: [String] = []
    /// Items macOS wouldn't let CLN touch (usually other apps' protected data). They can be
    /// retried once CLN has Full Disk Access.
    var blocked: [CleanItem] = []
}

enum Phase: Equatable { case idle, scanning, results, finished }

// MARK: - Modules

enum Module: String, CaseIterable, Identifiable {
    case activity, overview, cleanup, performance, applications, clutter, spaceLens

    var id: String { rawValue }

    var title: String { L(englishTitle) }

    var englishTitle: String {
        switch self {
        case .overview: "Overview"
        case .cleanup: "System Junk"
        case .performance: "Speed"
        case .applications: "Apps"
        case .clutter: "File Clutter"
        case .spaceLens: "Disk Map"
        case .activity: "My Activity"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "sparkles.rectangle.stack"
        case .cleanup: "trash.circle"
        case .performance: "gauge.with.dots.needle.67percent"
        case .applications: "square.stack.3d.up"
        case .clutter: "doc.on.doc"
        case .spaceLens: "square.grid.3x3.middle.filled"
        case .activity: "chart.bar.xaxis"
        }
    }

    var accent: Color { Theme.ink }

    var tagline: String { L(englishTagline) }

    var englishTagline: String {
        switch self {
        case .overview: "Every scan at once. Review what was found, then clean it all in one go."
        case .cleanup: "Clear caches, logs and developer leftovers that quietly pile up."
        case .performance: "Run maintenance tasks and decide what starts with your Mac."
        case .applications: "Remove apps completely, along with the files they leave behind."
        case .clutter: "Find big, old and duplicate files hiding in your folders."
        case .spaceLens: "See exactly what is taking up your disk, folder by folder."
        case .activity: "What CLN has done for your Mac so far."
        }
    }

    var features: [(symbol: String, title: String)] { englishFeatures.map { ($0.symbol, L($0.title)) } }

    var englishFeatures: [(symbol: String, title: String)] {
        switch self {
        case .overview: [("trash.circle", "System & AI Junk"), ("arrow.down.circle", "Old Downloads"), ("puzzlepiece.extension", "App Leftovers"), ("power", "Broken Startup Items")]
        case .cleanup: [("archivebox", "Caches, Logs & Developer Junk"), ("sparkles", "AI Clutter"), ("envelope", "Mail Attachments"), ("trash", "Trash Bins")]
        case .performance: [("wrench.and.screwdriver", "Maintenance Tasks"), ("power", "Login Items"), ("gearshape.2", "Background Items")]
        case .applications: [("xmark.bin", "Full Uninstall"), ("puzzlepiece.extension", "Leftover Files"), ("questionmark.folder", "Orphaned Data"), ("arrow.down.app", "Update Check")]
        case .clutter: [("externaldrive", "Large Files"), ("clock.arrow.circlepath", "Old Files"), ("doc.on.doc", "Duplicates"), ("arrow.down.circle", "Downloads")]
        case .spaceLens: [("square.grid.3x3", "Storage Map"), ("eye", "Hidden Files Included"), ("folder", "Largest Folders First")]
        case .activity: []
        }
    }
}

/// Section names, used as card titles and as keys for "last cleaned" dates.
enum Sec {
    static let junk = "System Junk"
    static let ai = "AI Clutter"
    static let mail = "Mail Attachments"
    static let trash = "Trash Bins"
    static let oldDownloads = "Old Downloads"
    static let leftovers = "App Leftovers"
    static let startup = "Broken Startup Items"
    static let large = "Large Files"
    static let old = "Old Files"
    static let dups = "Duplicates"
    static let downloads = "Downloads"

    static func info(_ s: String) -> (symbol: String, color: Color, blurb: String) {
        let i = englishInfo(s)
        return (i.symbol, i.color, L(i.blurb))
    }

    static func englishInfo(_ s: String) -> (symbol: String, color: Color, blurb: String) {
        switch s {
        case junk: ("archivebox.fill", .blue, "Caches, logs and developer leftovers that apps rebuild on their own.")
        case ai: ("sparkles", .orange, "Caches, logs and downloaded models from AI tools like Claude, Codex, Cursor and Ollama.")
        case mail: ("envelope.fill", .teal, "Attachments Mail saved when you opened them. They stay in your mailbox.")
        case trash: ("trash.fill", .gray, "Files already in your Trash. Cleaning empties it permanently.")
        case oldDownloads: ("arrow.down.circle.fill", .pink, "Downloads you haven't touched in over 3 months.")
        case leftovers: ("puzzlepiece.extension.fill", .indigo, "Support files left behind by apps that are no longer installed.")
        case startup: ("power.circle.fill", .red, "Startup items pointing to programs that no longer exist.")
        case large: ("externaldrive.fill", .purple, "Files of 100 MB or more.")
        case old: ("clock.arrow.circlepath", .brown, "Files of 10 MB or more not changed for over a year.")
        case dups: ("doc.on.doc.fill", .mint, "Identical copies. The oldest copy is kept and never listed.")
        case downloads: ("arrow.down.circle.fill", .pink, "Everything in your Downloads folder.")
        default: ("folder.fill", .gray, "")
        }
    }

    static func category(_ s: String) -> CleanCategory {
        switch s {
        case oldDownloads, large, old, dups, downloads: .personal
        case leftovers, "Apps": .apps
        default: .junk
        }
    }
}
