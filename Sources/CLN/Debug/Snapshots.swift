import AppKit
import SwiftUI

/// `CLN --snapshot <dir>` renders key screens to PNGs with real (read-only) scan data.
/// Used to check layouts without clicking through the app. Nothing is cleaned.
enum Snapshots {
    @MainActor
    static func run(to dir: String) {
        let activity = ActivityStore()
        let overview = SectionModel.overview()
        overview.groups = SectionModel.overviewScan()
        overview.phase = .results

        let aiReview = SectionModel.overview()
        aiReview.groups = overview.groups
        aiReview.phase = .results
        aiReview.reviewing = Sec.ai

        ScanTicker.shared.reset()
        for i in 0..<12_480 { ScanTicker.shared.saw(FS.lib("Caches/com.anthropic.claudefordesktop/Cache_Data/f_\(i)"), size: 180_000) }
        let diskMap = SpaceLensModel()
        diskMap.current = SpaceScanner.scan(FS.home.appendingPathComponent("Downloads"), cancel: CancelFlag()) { _ in }
        diskMap.phase = .results
        let speed = PerformanceModel()
        speed.items = LaunchScanner.scan()
        speed.phase = .results
        var blockedResult = CleanResult(freed: 13_540_000_000, count: 5)
        blockedResult.blocked = ["com.grammarly.safari.extension.ext2", "net.whatsapp.WhatsApp"].map {
            CleanItem(url: FS.lib("Containers/\($0)"), name: $0, detail: "", size: 0)
        }
        blockedResult.failures = blockedResult.blocked.map { "\($0.name): macOS protects this folder." }
        // Sizes like a home folder: four big folders and a long tail of small ones
        let homeMap = SpaceLensModel()
        let home = SpaceNode(url: FS.home, size: 0, isDirectory: true)
        let gb = 1_000_000_000.0
        let sizes: [(String, Double)] = [("Library", 71.05), ("Desktop", 29.01), ("Presence Dropbox", 26.17), ("short-form-studio", 22.29),
                                         ("Pictures", 0.9), ("Movies", 0.7), ("Documents", 0.5), ("Music", 0.4), ("Applications", 0.3),
                                         ("go", 0.2), (".npm", 0.1), (".cache", 0.05), (".zsh_history", 0.001)]
        for (name, size) in sizes {
            let child = SpaceNode(url: FS.home.appendingPathComponent(name), size: Int64(size * gb), isDirectory: true)
            child.parent = home
            home.children.append(child)
            home.size += child.size
        }
        homeMap.current = home
        homeMap.phase = .results
        let screens: [(String, AnyView)] = [
            ("0-scanning", AnyView(ScanningView(module: .overview, status: "Looking at AI tools…", onCancel: {}))),
            ("1-overview-intro", AnyView(SectionModuleView(model: SectionModel.overview(), showAutoClean: true) {
                AutoCleanCard().frame(maxWidth: 470) })),
            ("2-overview-cards", AnyView(SectionCardsView(model: overview, showAutoClean: true, scrolls: false))),
            ("3-ai-manager", AnyView(SectionModuleView(model: aiReview))),
            ("4-activity", AnyView(ActivityView(go: { _ in }, onScan: {}, scrolls: false))),
            ("4-activity-good", AnyView(ActivityView(go: { _ in }, onScan: {}, scrolls: false, previewHealth: "Good"))),
            ("4-activity-fair", AnyView(ActivityView(go: { _ in }, onScan: {}, scrolls: false, previewHealth: "Fair"))),
            ("4-activity-poor", AnyView(ActivityView(go: { _ in }, onScan: {}, scrolls: false, previewHealth: "Poor"))),
            ("5-disk-map-intro", AnyView(SpaceLensView(model: SpaceLensModel()))),
            ("6-disk-map-results", AnyView(SpaceLensView(model: diskMap))),
            ("6b-disk-map-home", AnyView(SpaceLensView(model: homeMap))),
            ("7-welcome-terms", AnyView(WelcomeTerms(onAgree: {}))),
            ("8-blocked", AnyView(DoneView(module: .applications, result: blockedResult, onDone: {}))),
            ("9-speed-background", AnyView(PerformanceView(model: speed, tab: 2, scrolls: false))),
        ]
        for (name, view) in screens {
            let content = HStack(spacing: 0) {
                Sidebar(selection: .constant(.overview))
                view.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 28)
            }
            .frame(width: 1280, height: 800)
            .background(Backdrop())
            .foregroundStyle(Theme.ink)
            .environmentObject(activity)
            .environment(\.colorScheme, .light)
            guard #available(macOS 13, *) else { return }
            let r = ImageRenderer(content: content)
            r.scale = 1
            if let img = r.nsImage, let tiff = img.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
            }
        }
        renderTransparentMockup(activity: activity, to: dir)
    }

    /// Mockup: CLN as a see-through milky glass window over a desktop wallpaper.
    @MainActor
    static func renderTransparentMockup(activity: ActivityStore, to dir: String) {
        guard let wall = NSImage(contentsOfFile: "/System/Library/Desktop Pictures/.thumbnails/Catalina Coast.heic") else { return }
        let canvas = CGSize(width: 1600, height: 1000)
        let win = CGRect(x: 160, y: 100, width: 1280, height: 800)
        let desktop = Image(nsImage: wall).resizable().scaledToFill().frame(width: canvas.width, height: canvas.height).clipped()

        let window = ZStack(alignment: .topLeading) {
            // The desktop behind the window, blurred and milky: what macOS's behind-window blur does
            desktop
                .offset(x: -win.minX, y: -win.minY)
                .frame(width: win.width, height: win.height, alignment: .topLeading)
                .blur(radius: 30)
                .clipped()
            Color(white: 0.85).opacity(0.20)
            HStack(spacing: 0) {
                Sidebar(selection: .constant(.overview))
                SectionModuleView(model: SectionModel.overview(), showAutoClean: true) { AutoCleanCard().frame(maxWidth: 470) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 28)
            }
            HStack(spacing: 8) {
                ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.79, blue: 0.25)], id: \.self) {
                    Circle().fill($0).frame(width: 12, height: 12)
                }
            }
            .padding(14)
        }
        .frame(width: win.width, height: win.height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.45), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 40, y: 20)

        let content = ZStack(alignment: .topLeading) {
            desktop
            window.offset(x: win.minX, y: win.minY)
        }
        .frame(width: canvas.width, height: canvas.height)
        .foregroundStyle(Theme.ink)
        .environmentObject(activity)
        .environment(\.colorScheme, .light)

        guard #available(macOS 13, *) else { return }
        let r = ImageRenderer(content: content)
        r.scale = 1
        if let img = r.nsImage, let tiff = img.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("8-transparent-mockup.png"))
        }
    }
}

extension SectionModel {
    /// The overview scan run synchronously (snapshot mode only).
    static func overviewScan() -> [CleanGroup] {
        var g = JunkScanner.scan { _ in }
        let orphans = AppScanner.orphanedLeftovers()
        if !orphans.isEmpty {
            g.append(CleanGroup(title: "Orphaned Leftovers", symbol: "questionmark.folder", section: Sec.leftovers, items: orphans))
        }
        let dl = ClutterScanner.downloads(olderThanDays: 90)
        if !dl.isEmpty { g.append(CleanGroup(title: Sec.oldDownloads, symbol: "arrow.down.circle", section: Sec.oldDownloads, items: dl)) }
        return g
    }

}
