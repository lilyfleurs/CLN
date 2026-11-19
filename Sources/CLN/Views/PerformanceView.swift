import AppKit
import SwiftUI

@MainActor
final class PerformanceModel: ObservableObject {
    @Published var phase: Phase = .idle
    @Published var items: [LaunchItem] = []
    @Published var running: String?
    @Published var taskOutcome: [String: Bool] = [:]
    /// Launch item being changed right now.
    @Published var busy: UUID?
    @Published var itemError: String?

    func scan() {
        phase = .scanning
        Task.detached {
            let found = LaunchScanner.scan()
            await MainActor.run { self.items = found; self.phase = .results }
        }
    }

    func run(_ task: MaintenanceTask, activity: ActivityStore) {
        running = task.id
        Task.detached {
            let ok = task.run()
            await MainActor.run {
                self.running = nil
                self.taskOutcome[task.id] = ok
                if ok { activity.recordTask(keys: [Module.performance.rawValue, "task." + task.id]) }
            }
        }
    }

    func remove(_ item: LaunchItem, activity: ActivityStore) {
        let size = FS.size(of: item.url)
        change(item) { LaunchControl.remove(item) } done: {
            self.items.removeAll { $0.id == item.id }
            activity.record(.junk, freed: size, count: 1, keys: [Module.performance.rawValue, Sec.startup])
            activity.recordRun()
            Chime.play()
        }
    }

    func setOn(_ item: LaunchItem, _ on: Bool) {
        change(item) { on ? LaunchControl.turnOn(item) : LaunchControl.turnOff(item) } done: {
            // Read the real state back from launchd
            if let fresh = LaunchScanner.scan().first(where: { $0.url == item.url }),
               let i = self.items.firstIndex(where: { $0.id == item.id }) {
                self.items[i] = fresh
            }
        }
    }

    private func change(_ item: LaunchItem, _ work: @escaping @Sendable () -> Bool, done: @escaping @MainActor () -> Void) {
        busy = item.id
        itemError = nil
        Task.detached {
            let ok = work()
            await MainActor.run {
                self.busy = nil
                if ok { done() } else { self.itemError = L("%@ couldn't be changed. If macOS asked for your password, it may have been cancelled.", item.label) }
            }
        }
    }
}

struct PerformanceView: View {
    @ObservedObject var model: PerformanceModel
    @EnvironmentObject private var activity: ActivityStore
    @State private var tab: Int
    @State private var toRemove: LaunchItem?
    /// Snapshots only: draw without a scroll view.
    var scrolls = true

    init(model: PerformanceModel, tab: Int = 0, scrolls: Bool = true) {
        self.model = model
        self._tab = State(initialValue: tab)
        self.scrolls = scrolls
    }

    private let accent = Module.performance.accent

    var body: some View {
        switch model.phase {
        case .idle, .finished:
            ModuleIntro(module: .performance, lastLabel: "Last maintenance", action: model.scan)
        case .scanning:
            ScanningView(module: .performance, status: "Reading startup items…")
        case .results:
            results
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button { model.phase = .idle } label: { Label(L("Back"), systemImage: "chevron.left").font(Theme.display(15, .regular)) }
                    .buttonStyle(.plain).foregroundStyle(accent)
                Spacer()
                GlassSegmented(selection: $tab, options: [
                    (0, L("Maintenance")),
                    (1, "\(L("Login Items")) (\(model.items.filter(\.isUser).count))"),
                    (2, "\(L("Background Items")) (\(model.items.filter { !$0.isUser }.count))"),
                ])
                Spacer()
                LastCleanedLabel(key: Module.performance.rawValue, prefix: L("Last maintenance"))
            }
            if scrolls { ScrollView { tabContent } } else { tabContent; Spacer(minLength: 0) }
        }
        .padding(28)
        .alert(L("Remove %@?", toRemove?.label ?? ""), isPresented: Binding(get: { toRemove != nil }, set: { if !$0 { toRemove = nil } })) {
            Button(L("Remove"), role: .destructive) { if let i = toRemove { model.remove(i, activity: activity) }; toRemove = nil }
            Button(L("Cancel"), role: .cancel) { toRemove = nil }
        } message: {
            Text(L("It stops now and won't start again. Its file goes to the Trash, so you can put it back.")
                 + (toRemove?.owner.map { " " + L("%@ may stop working properly or put it back the next time it updates.", $0) } ?? ""))
        }
    }

    private var tabContent: some View {
        VStack(spacing: 10) {
            switch tab {
            case 0: ForEach(MaintenanceTask.all) { taskRow($0) }
            case 1: loginItems
            default: backgroundItems
            }
        }
    }

    private func taskRow(_ t: MaintenanceTask) -> some View {
        HStack(spacing: 16) {
            IconTile(symbol: t.symbol, color: accent, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(t.title).font(Theme.display(15, .regular))
                    if t.needsAdmin {
                        Text(L("Asks for password")).font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.ink.opacity(0.1)))
                    }
                }
                Text(t.detail).font(.callout).foregroundStyle(.secondary)
                LastCleanedLabel(key: "task." + t.id, prefix: L("Last run")).font(.caption)
            }
            Spacer()
            if let ok = model.taskOutcome[t.id] {
                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundStyle(ok ? Theme.good : Theme.bad).font(.title3)
            }
            if model.running == t.id {
                ProgressView().controlSize(.small)
            } else {
                Button(L("Run")) { model.run(t, activity: activity) }.buttonStyle(PillButtonStyle(color: accent))
                    .disabled(model.running != nil)
            }
        }
        .glassCard(radius: 16, padding: 14)
    }

    @ViewBuilder private var loginItems: some View {
        HStack {
            Text(L("Startup agents installed for your account. Items marked Broken point to programs that no longer exist."))
                .foregroundStyle(.secondary)
            Spacer()
            Button(L("Open Login Items Settings")) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
            }
            .buttonStyle(GhostButtonStyle())
        }
        let user = model.items.filter(\.isUser)
        if user.isEmpty { Text(L("No startup agents in your account.")).foregroundStyle(.secondary).padding(30) }
        if let e = model.itemError { Text(e).font(.callout).foregroundStyle(Theme.bad) }
        ForEach(user) { launchRow($0, removable: true) }
    }

    @ViewBuilder private var backgroundItems: some View {
        HStack(alignment: .top) {
            Text(L("Helpers that apps installed for every account on this Mac: updaters, licence checks, VPN and sync services. Turn Off stops one and keeps it from starting again; you can turn it back on. Remove also moves its file to the Trash. Both ask for your password when the item is system-wide."))
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(L("Open Login Items Settings")) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
            }
            .buttonStyle(GhostButtonStyle())
            .help(L("Some apps register background items with macOS directly; switch those off under Allow in the Background."))
        }
        if let e = model.itemError { Text(e).font(.callout).foregroundStyle(Theme.bad) }
        ForEach(model.items.filter { !$0.isUser }) { launchRow($0, removable: true) }
    }

    private func stateChip(_ i: LaunchItem) -> some View {
        let text = i.disabled ? L("Off") : i.pid != nil ? L("Running") : i.loaded ? L("Waiting") : L("Not loaded")
        return Text(text.uppercased()).font(Theme.mono(9)).tracking(0.6)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(i.pid != nil && !i.disabled ? Theme.turquoise.opacity(0.35) : Theme.ink.opacity(0.08)))
            .help(i.pid != nil ? L("Running now (process %@)", "\(i.pid!)") : i.loaded ? L("Loaded; starts when needed") : "")
    }

    private func launchRow(_ i: LaunchItem, removable: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: i.isDaemon ? "gearshape.2.fill" : "power").font(.title3)
                .foregroundStyle(i.programExists ? accent : Theme.bad).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(i.label).font(Theme.display(15, .regular)).lineLimit(1)
                    if !i.programExists {
                        Text(L("Broken")).font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Theme.bad.opacity(0.35)))
                    }
                    if i.isDaemon { Text(L("System-wide")).font(.caption2).foregroundStyle(.secondary) }
                    stateChip(i)
                }
                Text((i.owner.map { L("From %@", $0) + " · " } ?? "") + (i.program.isEmpty ? FS.tilde(i.url.path) : FS.tilde(i.program)))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button { FS.reveal(i.url) } label: { Image(systemName: "magnifyingglass") }.buttonStyle(.plain).foregroundStyle(.secondary)
                .help(L("Show in Finder"))
            if model.busy == i.id {
                ProgressView().controlSize(.small)
            } else {
                Button(i.disabled ? L("Turn On") : L("Turn Off")) { model.setOn(i, i.disabled) }
                    .buttonStyle(GhostButtonStyle()).disabled(model.busy != nil)
                if removable { Button(L("Remove")) { toRemove = i }.buttonStyle(PillButtonStyle()).disabled(model.busy != nil) }
            }
        }
        .glassCard(radius: 14, padding: 12)
    }
}
