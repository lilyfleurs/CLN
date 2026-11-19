import AppKit

/// Drives one scan-and-clean screen: scan, show cards per section, review in the manager, clean.
@MainActor
final class SectionModel: ObservableObject {
    typealias Scanner = (URL, CancelFlag, @escaping (String) -> Void) -> [CleanGroup]

    let module: Module
    let sectionOrder: [String]
    let usesCards: Bool
    private let scanner: Scanner

    @Published var phase: Phase = .idle
    @Published var status = ""
    @Published var groups: [CleanGroup] = []
    @Published var root: URL
    /// Section open in the manager; "" means every section.
    @Published var reviewing: String?
    /// Bytes freed per section since the last scan, so cards can show "removed".
    @Published var cleanedSections: [String: Int64] = [:]
    @Published var lastResult: CleanResult?
    /// Apps screen only: available updates by app path, filled in after the scan.
    @Published var updates: [String: AppUpdate] = [:]
    @Published var checkingUpdates = false

    private var cancelFlag = CancelFlag()

    init(module: Module, sections: [String], usesCards: Bool = true, root: URL = FS.home, scanner: @escaping Scanner) {
        self.module = module
        self.sectionOrder = sections
        self.usesCards = usesCards
        self.root = root
        self.scanner = scanner
    }

    // MARK: Scanning

    func scan() {
        phase = .scanning
        status = "Starting…"
        cleanedSections = [:]
        lastResult = nil
        reviewing = nil
        ScanTicker.shared.reset()
        let flag = CancelFlag()
        cancelFlag = flag
        let scanner = scanner, root = root
        Task.detached(priority: .userInitiated) {
            let found = scanner(root, flag) { s in Task { @MainActor in self.status = s } }
            await MainActor.run {
                if flag.isCancelled { self.phase = .idle; return }
                self.groups = found
                self.phase = .results
                if self.module == .applications { self.checkForUpdates() }
            }
        }
    }

    func cancel() { cancelFlag.cancel() }

    func checkForUpdates() {
        checkingUpdates = true
        Task { @MainActor in
            let r = await UpdateChecker.check()
            self.updates = Dictionary(r.updates.map { ($0.appURL.path, $0) }, uniquingKeysWith: { a, _ in a })
            self.checkingUpdates = false
        }
    }

    func startOver() {
        phase = .idle
        groups = []
        reviewing = nil
        lastResult = nil
    }

    // MARK: Sections

    var sections: [String] {
        sectionOrder.filter { s in groups.contains { $0.section == s } || cleanedSections[s] != nil }
    }

    func groups(in section: String?) -> [CleanGroup] {
        guard let section, !section.isEmpty else { return groups }
        return groups.filter { $0.section == section }
    }

    func size(_ s: String?) -> Int64 { groups(in: s).totalSize }
    func selectedSize(_ s: String?) -> Int64 { groups(in: s).reduce(0) { $0 + $1.selectedSize } }
    func selectedCount(_ s: String?) -> Int { groups(in: s).reduce(0) { $0 + $1.selectedCount } }
    func itemCount(_ s: String?) -> Int { groups(in: s).reduce(0) { $0 + $1.items.count } }

    func checkState(_ s: String?) -> CheckState {
        let sel = selectedCount(s), all = itemCount(s)
        return sel == 0 ? .off : sel == all ? .on : .mixed
    }

    func setSelected(_ s: String?, _ on: Bool) {
        for gi in groups.indices where s == nil || s!.isEmpty || groups[gi].section == s {
            for ii in groups[gi].items.indices { groups[gi].items[ii].selected = on }
        }
    }

    func includesTrash(_ s: String?) -> Bool {
        groups(in: s).contains { $0.section == Sec.trash && $0.selectedCount > 0 }
    }

    // MARK: Cleaning

    /// Cleans the selected items in `section` (nil = everything selected on this screen),
    /// or only in the groups listed in `only`.
    func clean(section: String?, only: Set<UUID>? = nil, activity: ActivityStore) {
        let pool = groups(in: section).filter { only?.contains($0.id) ?? true }
        let trashGroups = pool.filter { $0.section == Sec.trash }
        let emptyTrash = trashGroups.contains { $0.selectedCount > 0 }
        let trashSize = trashGroups.totalSize
        let trashCount = trashGroups.reduce(0) { $0 + $1.items.count }
        let work = Dictionary(grouping: pool.filter { $0.section != Sec.trash }.flatMap { g in
            g.items.filter(\.selected).map { (g.section, $0) }
        }, by: \.0).mapValues { $0.map(\.1) }
        let groupOf = Dictionary(pool.flatMap { g in g.items.map { ($0.id, g.id) } }, uniquingKeysWith: { a, _ in a })

        phase = .scanning
        status = "Moving items to the Trash…"
        Task.detached(priority: .userInitiated) {
            var total = CleanResult()
            var moved = Set<URL>()
            var perSection: [String: (Int64, Int)] = [:]
            for (sec, items) in work {
                if sec == Sec.startup { items.forEach { LaunchScanner.unload($0.url) } }
                var items = items
                if sec == "Apps" {
                    await MainActor.run { self.status = "Quitting apps…" }
                    // An app that won't quit is left in place, along with everything that belongs to it.
                    let stuck = items.filter { $0.url.pathExtension == "app" && !AppQuitter.quit($0.url) }
                    for app in stuck { total.failures.append("\(app.name): still open, quit it and try again.") }
                    let stuckGroups = Set(stuck.compactMap { groupOf[$0.id] })
                    items.removeAll { groupOf[$0.id].map(stuckGroups.contains) ?? false }
                }
                let (r, m) = FS.trash(items, allowSystem: sec == "Apps")
                total.freed += r.freed
                total.count += r.count
                total.failures += r.failures
                perSection[sec] = (r.freed, r.count)
                moved.formUnion(m)
            }
            var trashEmptied = false
            if emptyTrash {
                await MainActor.run { self.status = "Emptying the Trash…" }
                if FS.emptyTrash() {
                    trashEmptied = true
                    total.freed += trashSize
                    total.count += trashCount
                    perSection[Sec.trash] = (trashSize, trashCount)
                } else {
                    total.failures.append("Trash: Finder couldn't empty the Trash.")
                }
            }
            let (movedURLs, emptied, sections, result) = (moved, trashEmptied, perSection, total)
            await MainActor.run {
                let (moved, trashEmptied, perSection, total) = (movedURLs, emptied, sections, result)
                self.groups = self.groups.removing(moved)
                if trashEmptied { self.groups.removeAll { $0.section == Sec.trash } }
                for (sec, (freed, count)) in perSection where count > 0 {
                    activity.record(Sec.category(sec), freed: freed, count: count, keys: [sec, self.module.rawValue])
                    self.cleanedSections[sec, default: 0] += freed
                }
                if total.count > 0 { activity.recordRun(); Chime.play() }
                self.lastResult = total
                self.reviewing = nil
                self.phase = self.usesCards ? .results : .finished
            }
        }
    }
}

enum CheckState { case on, off, mixed }

/// Quits a running app before it is uninstalled, so it can't recreate its files on the way out.
enum AppQuitter {
    /// Asks the app to quit and waits up to 8 seconds. Returns true when it is no longer running.
    static func quit(_ app: URL) -> Bool {
        let path = app.standardizedFileURL.path
        let running = NSWorkspace.shared.runningApplications.filter { $0.bundleURL?.standardizedFileURL.path == path }
        guard !running.isEmpty else { return true }
        running.forEach { $0.terminate() }
        for _ in 0..<40 {
            if running.allSatisfy(\.isTerminated) { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return running.allSatisfy(\.isTerminated)
    }
}

// MARK: - Screens built on SectionModel

extension SectionModel {
    static func overview() -> SectionModel {
        SectionModel(module: .overview,
                     sections: [Sec.junk, Sec.ai, Sec.mail, Sec.trash, Sec.oldDownloads, Sec.leftovers, Sec.startup]) { _, _, progress in
            var g = JunkScanner.scan(progress: progress)
            progress("Looking at old downloads…")
            let dl = ClutterScanner.downloads(olderThanDays: 90)
            if !dl.isEmpty {
                g.append(CleanGroup(title: Sec.oldDownloads, symbol: "arrow.down.circle", subtitle: Sec.info(Sec.oldDownloads).blurb,
                                    section: Sec.oldDownloads, items: dl))
            }
            progress("Looking for leftovers of removed apps…")
            let orphans = AppScanner.orphanedLeftovers()
            if !orphans.isEmpty {
                g.append(CleanGroup(title: "Orphaned Leftovers", symbol: "questionmark.folder", subtitle: Sec.info(Sec.leftovers).blurb,
                                    section: Sec.leftovers, items: orphans))
            }
            progress("Checking startup items…")
            let broken = LaunchScanner.brokenItems()
            if !broken.isEmpty {
                g.append(CleanGroup(title: "Broken Login Items", symbol: "power", subtitle: Sec.info(Sec.startup).blurb,
                                    section: Sec.startup, items: broken))
            }
            return g
        }
    }

    static func cleanup() -> SectionModel {
        SectionModel(module: .cleanup, sections: [Sec.junk, Sec.ai, Sec.mail, Sec.trash]) { _, _, progress in
            JunkScanner.scan(progress: progress)
        }
    }

    static func clutter() -> SectionModel {
        SectionModel(module: .clutter, sections: [Sec.large, Sec.old, Sec.dups, Sec.downloads]) { root, cancel, progress in
            ClutterScanner.scan(root: root, cancel: cancel, progress: progress)
        }
    }

    static func apps() -> SectionModel {
        SectionModel(module: .applications, sections: [Sec.leftovers, "Apps"], usesCards: false) { _, _, progress in
            AppScanner.scan(progress: progress)
        }
    }
}
