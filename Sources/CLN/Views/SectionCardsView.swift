import SwiftUI

/// Scan summary: a headline, Review All / Clean All, and one card per section.
struct SectionCardsView: View {
    @ObservedObject var model: SectionModel
    @EnvironmentObject private var activity: ActivityStore
    var showAutoClean = false
    /// Snapshot rendering can't draw scroll views.
    var scrolls = true

    /// Section to clean after confirmation; "" means Clean All.
    @State private var pending: String?
    @State private var showBanner = true

    private var accent: Color { model.module.accent }

    var body: some View {
        Group {
            if scrolls { ScrollView { content } } else { content }
        }
        .whenChanged(model.lastResult?.freed) { _ in showBanner = true }
        .alert(alertTitle, isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button(confirmTitle, role: .destructive) {
                let s = pending
                pending = nil
                if s == Sec.trash { model.setSelected(Sec.trash, true) }
                model.clean(section: s?.isEmpty == true ? nil : s, activity: activity)
            }
            Button(L("Cancel"), role: .cancel) { pending = nil }
        } message: {
            Text(alertMessage)
        }
    }

    private var content: some View {
            VStack(spacing: 26) {
                topBar
                headline
                if let r = model.lastResult, showBanner {
                    ResultBanner(result: r, accent: accent) { showBanner = false }.frame(maxWidth: 760)
                }
                if model.sectionOrder.contains(Sec.trash), !FS.hasFullDiskAccess {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield").font(.title2).foregroundStyle(Theme.warn)
                        Text(L("Mail attachments and the Trash are hidden until you give CLN Full Disk Access in System Settings. Then quit and reopen CLN and scan again."))
                            .font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        Button(L("Open Settings")) { FS.openFullDiskAccessSettings() }.buttonStyle(GhostButtonStyle())
                    }
                    .glassCard(radius: 16, padding: 14)
                    .frame(maxWidth: 760)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 18)], spacing: 18) {
                    ForEach(model.sections, id: \.self) { s in
                        SectionCard(model: model, section: s,
                                    onReview: { model.reviewing = s },
                                    onClean: { pending = s })
                    }
                }
                if showAutoClean { AutoCleanCard() }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
    }

    private var topBar: some View {
        HStack {
            Button { model.startOver() } label: { Label(L("Start Over"), systemImage: "arrow.counterclockwise").font(Theme.display(15, .regular)) }
                .buttonStyle(.plain)
            Spacer()
            Text(model.module.title).font(Theme.display(15, .regular))
            Spacer()
            LastCleanedLabel(key: model.module.rawValue)
        }
        .padding(.top, 8)
    }

    private var headline: some View {
        let total = model.size(nil)
        return VStack(spacing: 16) {
            SwissLabel(text: "\(model.module.number) — \(model.module.title) · \(L("Results"))")
            Text(total > 0 ? L("We found %@ you could clean up.", FS.format(total)) : L("Your Mac is spotless."))
                .font(Theme.caps(26, .bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
            Text(total > 0 ? L("Recommended items are already selected. Tick or untick a card to include it in Clean All.")
                           : L("Nothing left to clean from this scan."))
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Button(L("Review All")) { model.reviewing = "" }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(model.groups.isEmpty)
                Button {
                    pending = ""
                } label: {
                    Label("\(trashWording ? L("Move All to Trash") : L("Clean All")) · \(FS.format(cleanAllSize))",
                          systemImage: trashWording ? "trash" : "sparkles")
                }
                .buttonStyle(PillButtonStyle(color: accent, large: true))
                .disabled(model.selectedCount(nil) == 0)
            }
        }
        .padding(.top, 10)
    }

    /// File Clutter works on your own files, so its buttons say what happens: they go to the Trash.
    private var trashWording: Bool { model.module == .clutter }

    private var cleanAllSize: Int64 {
        model.selectedSize(nil) - model.groups(in: Sec.trash).reduce(0) { $0 + $1.selectedSize }
            + (model.includesTrash(nil) ? model.size(Sec.trash) : 0)
    }

    private var alertTitle: String {
        guard let p = pending else { return "" }
        if p.isEmpty || trashWording { return L("Move %@ items to the Trash?", "\(model.selectedCount(p.isEmpty ? nil : p))") }
        if p == Sec.trash { return L("Empty the Trash permanently?") }
        return L("Clean %@ items from %@?", "\(model.selectedCount(p))", L(p))
    }

    private var confirmTitle: String {
        pending == Sec.trash ? L("Empty Trash") : trashWording ? L("Move to Trash") : pending == "" ? L("Clean All") : L("Clean")
    }

    private var alertMessage: String {
        guard let p = pending else { return "" }
        if p == Sec.trash { return L("All %@ in the Trash will be deleted. This can't be undone.", FS.format(model.size(Sec.trash))) }
        var msg = L("This frees about %@. Items go to the Trash so you can put them back.", FS.format(p.isEmpty ? cleanAllSize : model.selectedSize(p)))
        if p.isEmpty && model.includesTrash(nil) { msg += " " + L("The Trash Bins card is ticked, so the Trash will also be emptied permanently.") }
        return msg
    }
}

struct SectionCard: View {
    @ObservedObject var model: SectionModel
    let section: String
    let onReview: () -> Void
    let onClean: () -> Void

    var body: some View {
        let info = Sec.info(section)
        let size = model.size(section)
        let freed = model.cleanedSections[section]
        let cleaned = freed != nil
        let done = cleaned && size == 0
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                if !done {
                    CheckBox(state: model.checkState(section), color: model.module.accent) {
                        model.setSelected(section, model.checkState(section) == .off)
                    }
                    .help(L("Include in Clean All"))
                    .padding(.top, 4)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(cleaned ? L("%@ of %@ removed", FS.format(freed!), L(section)) : L("%@ of %@ found", FS.format(size), L(section)))
                        .font(Theme.display(20, .regular))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(cleaned ? (done ? L("All clean now.") : L("%@ left that wasn't selected.", FS.format(size))) : info.blurb).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                IconTile(symbol: info.symbol, color: info.color, size: 46)
            }
            Spacer(minLength: 8)
            LastCleanedLabel(key: section).font(.caption)
            HStack {
                if done {
                    Label(L("Done"), systemImage: "checkmark.circle.fill").foregroundStyle(Theme.good).font(Theme.display(15, .regular))
                } else {
                    Text(model.selectedCount(section) == 0 ? L("None selected") : L("%@ selected", FS.format(model.selectedSize(section))))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !done {
                    Button(L("Review"), action: onReview).buttonStyle(PillButtonStyle())
                    Button(section == Sec.trash ? L("Empty") : model.module == .clutter ? L("Move to Trash") : L("Clean"), action: onClean)
                        .buttonStyle(PillButtonStyle(color: model.module.accent))
                        .disabled(section == Sec.trash ? size == 0 : model.selectedCount(section) == 0)
                }
            }
        }
        .frame(minHeight: 190)
        .glassCard()
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.ink.opacity(cleaned ? 0.16 : 0)))
    }
}

/// Lets the user pick how often System Junk is cleaned automatically.
struct AutoCleanCard: View {
    var accent: Color = Theme.ink
    @EnvironmentObject private var activity: ActivityStore
    @State private var frequency = AutoClean.frequency
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 18) {
                IconTile(symbol: "calendar.badge.clock", color: accent, size: 50)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Auto-Clean")).font(Theme.display(20, .regular))
                    Text(L("Cleans recommended System Junk (app caches, logs, Xcode build data) on a schedule, even when CLN is closed. Personal files, AI tools, Mail and the Trash are never touched automatically."))
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            GlassSegmented(selection: $frequency, options: AutoFrequency.allCases.map { ($0, $0 == .biweekly ? L("2 weeks") : $0.label) })
                .whenChanged(frequency) { f in error = AutoClean.set(f) }
                HStack(spacing: 18) {
                    if let next = AutoClean.nextRun, frequency != .off {
                        Label(L("Next: %@", next.formatted(date: .abbreviated, time: .shortened)), systemImage: "calendar")
                    }
                    if let last = AutoClean.lastRun {
                        Label(L("Last auto-clean: %@ · %@ freed", last.formatted(date: .abbreviated, time: .shortened), FS.format(AutoClean.lastFreed)),
                              systemImage: "clock.arrow.circlepath")
                    } else {
                        Label(L("Last auto-clean: never"), systemImage: "clock.arrow.circlepath")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
                if let error { Text(error).font(.caption).foregroundStyle(Theme.warn) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

/// Intro → scanning → cards (or manager) → done, for any SectionModel screen.
struct SectionModuleView<Accessory: View>: View {
    @ObservedObject var model: SectionModel
    @EnvironmentObject private var activity: ActivityStore
    var showAutoClean = false
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        switch model.phase {
        case .idle:
            ModuleIntro(module: model.module, accessory: accessory, action: model.scan)
        case .scanning:
            ScanningView(module: model.module, status: model.status, onCancel: model.cancel)
        case .results:
            if let r = model.reviewing {
                ManagerView(model: model, section: r)
            } else if model.usesCards {
                SectionCardsView(model: model, showAutoClean: showAutoClean)
            } else {
                ManagerView(model: model, section: nil)
            }
        case .finished:
            DoneView(module: model.module, result: model.lastResult ?? CleanResult()) {
                model.phase = model.groups.isEmpty ? .idle : .results
            }
        }
    }
}

extension SectionModuleView where Accessory == EmptyView {
    init(model: SectionModel, showAutoClean: Bool = false) {
        self.init(model: model, showAutoClean: showAutoClean, accessory: { EmptyView() })
    }
}
