import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var activity: ActivityStore
    let go: (Module) -> Void
    let onScan: () -> Void
    /// Snapshot rendering can't draw scroll views.
    var scrolls = true
    /// Snapshots only: show this health state instead of the measured one.
    var previewHealth: String? = nil
    @State private var disk = DiskInfo.current()

    private let accent = Module.activity.accent
    private let colors: [CleanCategory: Color] = [.junk: Theme.ink, .personal: Theme.ink.opacity(0.5), .apps: Theme.ink.opacity(0.22)]

    var body: some View {
        Group {
            if scrolls { ScrollView { content } } else { content }
        }
        .onAppear {
            activity.reload()
            disk = DiskInfo.current()
        }
    }

    private var content: some View {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        SwissLabel(text: "\(Module.activity.number) — \(L("My Activity")) · \(L("since %@", activity.stats.since.formatted(date: .long, time: .omitted)))")
                        Text(L("MY ACTIVITY")).font(Theme.caps(44, .bold)).tracking(1)
                    }
                    Spacer()
                    Button(L("Scan"), action: onScan)
                        .buttonStyle(PillButtonStyle(large: true, scan: true))
                        .keyboardShortcut(.defaultAction)
                }
                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 18) {
                        healthCard.fixedSize(horizontal: false, vertical: true)
                        lastCleanedCard
                    }
                    VStack(spacing: 18) {
                        AutoCleanCard()
                        recommendations
                        cleanedCard
                    }
                }
            }
            .padding(32)
    }

    private var health: (String, Color) {
        switch previewHealth {
        case "Poor": return ("Poor", Theme.bad)
        case "Fair": return ("Fair", Theme.warn)
        case "Good": return ("Good", .white)
        default: break
        }
        let free = 1 - disk.usedFraction
        let stale = activity.stats.lastCleanup.map { Date().timeIntervalSince($0) > 30 * 86_400 } ?? true
        if free < 0.1 { return ("Poor", Theme.bad) }
        if free < 0.25 || stale { return ("Fair", Theme.warn) }
        return ("Good", .white)
    }

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Mac Health")).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Text(L(health.0)).font(Theme.display(38)).foregroundStyle(Theme.ink)
                Image(systemName: "laptopcomputer").font(.system(size: 34)).foregroundStyle(.secondary)
            }
            Text(Host.current().localizedName ?? "This Mac").foregroundStyle(.secondary)
            Spacer(minLength: 6)
            HStack {
                Text(L("Macintosh HD")).font(Theme.display(15, .regular))
                Spacer()
                Text(L("%@ of %@ used", FS.format(disk.used), FS.format(disk.total))).font(.callout)
            }
            ProgressView(value: disk.usedFraction).tint(disk.usedFraction > 0.9 ? Theme.bad : accent)
            Text(L("%@ available", FS.format(disk.available))).font(.caption).foregroundStyle(.secondary)
            Hairline().padding(.top, 4)
            HStack {
                stat("\(activity.stats.cleanups)", L("Cleanups"))
                stat("\(activity.stats.itemsRemoved)", L("Items removed"))
                stat("\(activity.stats.tasksRun)", L("Tasks run"))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
        .glassCard()
        // Good: a plain 15% white over the glass. Fair and Poor: the alert colour glows through
        // from behind the glass, with a thin wash of it on top.
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(health.0 == "Good" ? Color.white.opacity(0.15) : health.1.opacity(0.38))
            .blur(radius: health.0 == "Good" ? 0 : 6))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(LinearGradient(colors: [.white.opacity(0.12), health.1.opacity(0.12), health.1.opacity(0.18)],
                                 startPoint: .top, endPoint: .bottom))
            .opacity(health.0 == "Good" ? 0 : 1)
            .allowsHitTesting(false))
    }

    private var cleanedCard: some View {
        let total = max(activity.totalCleaned, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text(L("Storage Cleaned")).foregroundStyle(.secondary)
            Text(FS.format(activity.totalCleaned)).font(Theme.display(38))
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(CleanCategory.allCases, id: \.self) { c in
                        let w = geo.size.width * CGFloat(activity.cleaned(c)) / CGFloat(total)
                        if w > 0 { Capsule().fill(colors[c]!).frame(width: max(w - 2, 4)) }
                    }
                    if activity.totalCleaned == 0 { Capsule().fill(Theme.ink.opacity(0.1)) }
                }
            }
            .frame(height: 14)
            ForEach(CleanCategory.allCases, id: \.self) { c in
                HStack {
                    Circle().fill(colors[c]!).frame(width: 8, height: 8)
                    Text(c.rawValue)
                    Spacer()
                    Text(FS.format(activity.cleaned(c))).font(.body.weight(.semibold).monospacedDigit())
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
        .glassCard()
    }

    private var lastCleanedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Last Cleaned")).font(Theme.display(20, .regular))
            ForEach(Module.allCases.filter { $0 != .activity }) { m in
                HStack(spacing: 12) {
                    IconTile(symbol: m.symbol, color: m.accent, size: 28)
                    Text(m.title)
                    Spacer()
                    if let d = activity.lastCleaned(m.rawValue) {
                        Text("\(d.formatted(date: .abbreviated, time: .shortened)) · \(FS.relative(d))")
                            .font(.callout).foregroundStyle(.secondary)
                    } else {
                        Text(L("Never")).font(.callout).foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { go(m) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassCard()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 28, weight: .semibold).monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var recommendations: some View {
        var recs: [(String, String, Module)] = []
        if let last = activity.stats.lastCleanup {
            if Date().timeIntervalSince(last) > 14 * 86_400 {
                recs.append((L("It's time to care for your Mac"), L("Your last cleanup was %@. Run Overview to catch up.", FS.relative(last)), .overview))
            }
        } else {
            recs.append((L("Run your first scan"), L("Overview checks everything at once in about a minute."), .overview))
        }
        if disk.usedFraction > 0.8 {
            recs.append((L("Your disk is %@ full", "\(Int(disk.usedFraction * 100))%"), L("Disk Map shows which folders take the most space."), .spaceLens))
        }
        if AutoClean.frequency == .off {
            recs.append((L("Turn on Auto-Clean"), L("Keep junk from piling up without thinking about it."), .overview))
        }
        if activity.lastCleaned(Module.clutter.rawValue) == nil {
            recs.append((L("Look for duplicates"), L("File Clutter finds identical copies and big forgotten files."), .clutter))
        }
        return VStack(alignment: .leading, spacing: 10) {
            Text(recs.count == 1 ? L("1 Recommendation") : L("%@ Recommendations", "\(recs.count)")).font(Theme.display(20, .regular))
            ForEach(recs, id: \.0) { r in
                HStack(alignment: .top, spacing: 12) {
                    IconTile(symbol: r.2.symbol, color: r.2.accent, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.0).font(Theme.display(15, .regular))
                        Text(r.1).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L("Go")) { go(r.2) }.buttonStyle(GhostButtonStyle())
                }
            }
            if recs.isEmpty { Text(L("Everything looks good.")).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassCard()
    }
}
