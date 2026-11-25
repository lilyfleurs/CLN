import AppKit
import QuickLook
import SwiftUI

/// Two-pane review screen: groups on the left, their items on the right, clean button at the bottom.
struct ManagerView: View {
    @ObservedObject var model: SectionModel
    @EnvironmentObject private var activity: ActivityStore
    /// nil or "" shows every section.
    let section: String?

    enum SortKey: String, CaseIterable { case size = "Size", name = "Name", date = "Date" }

    @State private var currentGroup: UUID?
    @State private var sort: SortKey = .size
    @State private var query = ""
    @State private var confirm = false
    /// App group waiting for the "Uninstall …?" confirmation.
    @State private var uninstallGroup: UUID?
    /// Highlighted file (clicked or moved to with the arrow keys) and the one under the pointer.
    @State private var currentItem: UUID?
    @State private var hoveredItem: UUID?
    @State private var preview: URL?
    @FocusState private var focused: Bool

    private var accent: Color { model.module.accent }
    private var visibleGroups: [CleanGroup] { model.groups(in: section) }
    private var isTrash: Bool { section == Sec.trash }
    private var isApps: Bool { model.module == .applications }
    /// Names of the apps whose bundle is selected.
    private var selectedApps: [String] {
        model.groups(in: section).filter { g in g.items.contains { $0.selected && $0.url.pathExtension == "app" } }.map(\.title)
    }
    private var confirmTitle: String {
        if isTrash { return L("Empty the Trash permanently?") }
        let apps = selectedApps
        if isApps, apps.count == 1 { return L("Uninstall %@?", apps[0]) }
        if isApps, apps.count > 1 { return L("Uninstall %@ apps?", "\(apps.count)") }
        return L("Move %@ items to the Trash?", "\(model.selectedCount(section))")
    }
    private var confirmMessage: String {
        if isTrash { return L("All %@ in the Trash will be deleted. This can't be undone.", FS.format(model.size(Sec.trash))) }
        if isApps, !selectedApps.isEmpty {
            return L("The apps and the leftover files you selected (%@) go to the Trash. Open apps are quit first. Until you empty the Trash, you can put them back.",
                     FS.format(model.selectedSize(section)))
        }
        return L("This frees %@. Until you empty the Trash, you can put items back.", FS.format(model.selectedSize(section)))
    }
    private var title: String { (section?.isEmpty ?? true) ? model.module.title : L(section!) }

    private var groupIndex: Int? {
        let id = currentGroup ?? visibleGroups.first?.id
        return model.groups.firstIndex { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            HStack(spacing: 0) {
                sidebar.frame(width: 300)
                Divider().opacity(0.3)
                if let gi = groupIndex, model.groups.indices.contains(gi) {
                    itemsPane(gi)
                } else {
                    Text(L("Nothing left to review here.")).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Divider().opacity(0.3)
            footer
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        // Like Finder: Space previews the file under the pointer (or the highlighted one),
        // the arrow keys move the highlight.
        .quickLookPreview($preview)
        .focusable()
        .noFocusRing()
        .focused($focused)
        .onAppear { focused = true }
        .onListKeys(space: {
            if preview != nil { preview = nil; return true }
            guard let url = itemURL(hoveredItem ?? currentItem) else { return false }
            preview = url
            return true
        }, down: { moveCurrent(1) }, up: { moveCurrent(-1) })
        .alert(confirmTitle, isPresented: $confirm) {
            Button(isTrash ? L("Empty Trash") : isApps && !selectedApps.isEmpty ? L("Uninstall") : L("Move to Trash"), role: .destructive) {
                if isTrash { model.setSelected(Sec.trash, true) }
                model.clean(section: section, activity: activity)
            }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
        .alert(L("Uninstall %@?", uninstallTarget?.title ?? ""),
               isPresented: Binding(get: { uninstallGroup != nil }, set: { if !$0 { uninstallGroup = nil } })) {
            Button(L("Uninstall"), role: .destructive) {
                if let id = uninstallGroup {
                    setGroup(id, true)
                    model.clean(section: section, only: [id], activity: activity)
                }
                uninstallGroup = nil
            }
            Button(L("Cancel"), role: .cancel) { uninstallGroup = nil }
        } message: {
            if let g = uninstallTarget {
                Text(L("%@ and all %@ of its files (%@) go to the Trash. If it's open, it is quit first. Until you empty the Trash, you can put them back.",
                       g.title, "\(g.items.count)", FS.format(g.totalSize)))
            }
        }
    }

    private var uninstallTarget: CleanGroup? { model.groups.first { $0.id == uninstallGroup } }

    private var header: some View {
        HStack {
            Button {
                if model.reviewing != nil { model.reviewing = nil } else { model.startOver() }
            } label: { Label(L("Back"), systemImage: "chevron.left").font(Theme.display(15, .regular)) }
                .buttonStyle(.plain).foregroundStyle(accent)
            Spacer()
            VStack(spacing: 2) {
                Text(title).font(Theme.display(15, .regular))
                if model.module == .applications {
                    Text(model.checkingUpdates ? L("Checking for updates…")
                         : model.updates.isEmpty ? L("All apps are up to date.") : L("%@ updates available", "\(model.updates.count)"))
                        .font(Theme.mono(10)).foregroundStyle(Theme.ink.opacity(0.55))
                }
                LastCleanedLabel(key: (section?.isEmpty ?? true) ? model.module.rawValue : section!).font(.caption)
            }
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(L("Search"), text: $query).textFieldStyle(.plain).frame(width: 120)
                Picker(L("Sort by"), selection: $sort) {
                    ForEach(SortKey.allCases, id: \.self) { Text(L($0.rawValue)) }
                }
                .frame(width: 140)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if let section, !section.isEmpty {
                    Text(L(section)).font(Theme.display(20, .regular))
                    Text(Sec.info(section).blurb).font(.callout).foregroundStyle(.secondary).padding(.bottom, 10)
                }
                ForEach(visibleGroups) { g in
                    let selected = g.id == (currentGroup ?? visibleGroups.first?.id)
                    HStack(spacing: 10) {
                        CheckBox(state: g.selectedCount == 0 ? .off : g.selectedCount == g.items.count ? .on : .mixed, color: accent) {
                            setGroup(g.id, g.selectedCount == 0)
                        }
                        if let icon = g.iconPath { FileIcon(path: icon, size: 30) }
                        else { IconTile(symbol: g.symbol, color: Sec.info(g.section).color, size: 30) }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L(g.title)).font(Theme.display(15, .regular)).lineLimit(1)
                            Text(FS.format(g.totalSize)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let path = g.iconPath, let u = model.updates[path] {
                            Button(L("Update %@", u.latest)) { NSWorkspace.shared.open(u.link ?? u.appURL) }
                                .buttonStyle(PillButtonStyle())
                                .help(u.fromAppStore ? L("Open App Store") : L("Open App"))
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Theme.ink.opacity(0.07) : .clear))
                    .contentShape(Rectangle())
                    .onTapGesture { currentGroup = g.id; currentItem = nil }
                }
            }
            .padding(18)
        }
    }

    private func itemsPane(_ gi: Int) -> some View {
        let group = model.groups[gi]
        let ids = sortedIDs(group)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L(group.title)).font(Theme.display(20, .regular))
                    if !group.subtitle.isEmpty { Text(L(group.subtitle)).foregroundStyle(.secondary) }
                }
                Spacer()
                if group.section == "Apps" {
                    Button(L("Uninstall")) { uninstallGroup = group.id }
                        .buttonStyle(PillButtonStyle())
                        .help(L("Removes the app and everything it left on your Mac"))
                }
            }
            if group.section == "Apps" {
                Text(L("Uninstalling removes the app and the files below: settings, caches, containers, logs and helpers that stay behind when you only drag an app to the Trash. They only go together with the app, so apps you keep never lose their logins or settings."))
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Menu("\(L("Select")): \(group.selectedCount == 0 ? L("None") : group.selectedCount == group.items.count ? L("All") : "\(group.selectedCount)")") {
                    Button(L("All")) { setGroup(group.id, true) }
                    Button(L("None")) { setGroup(group.id, false) }
                }
                .menuStyle(.borderlessButton).fixedSize().foregroundStyle(accent)
                Spacer()
                Text(L("%@ items · %@", "\(group.items.count)", FS.format(group.totalSize))).font(.callout).foregroundStyle(.secondary)
            }
            ScrollViewReader { scroller in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(ids, id: \.self) { id in
                        if let ii = model.groups[gi].items.firstIndex(where: { $0.id == id }) {
                            ItemRow(item: itemBinding(gi, ii), accent: accent, fallback: group.symbol,
                                    isCurrent: currentItem == id,
                                    onClick: { currentItem = id; focused = true },
                                    onHover: { hoveredItem = $0 ? id : (hoveredItem == id ? nil : hoveredItem) },
                                    onPreview: { preview = model.groups[gi].items[ii].url })
                        }
                    }
                }
            }
            // keep the highlighted file in view while moving with the arrow keys
            .whenChanged(currentItem) { id in if let id { scroller.scrollTo(id) } }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
        HStack {
            Spacer()
            let count = model.selectedCount(section)
            Text(count == 0 ? L("No items selected") : L("%@ selected", "\(count)")).font(Theme.display(15, .regular))
            Text(L("|")).foregroundStyle(.secondary)
            Text(FS.format(model.selectedSize(section))).foregroundStyle(.secondary)
            Spacer()
            Button(isTrash ? L("Empty Trash") : isApps ? (selectedApps.isEmpty ? L("Remove") : L("Uninstall"))
                   : model.module == .clutter ? L("Move to Trash") : L("Clean Up")) { confirm = true }
                .buttonStyle(PillButtonStyle(color: accent))
                .disabled(isTrash ? model.size(Sec.trash) == 0 : count == 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private func sortedIDs(_ g: CleanGroup) -> [UUID] {
        var items = g.items
        if !query.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.detail.localizedCaseInsensitiveContains(query) }
        }
        switch sort {
        case .size: items.sort { $0.size > $1.size }
        case .name: items.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .date: items.sort { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        }
        return items.map(\.id)
    }

    private func itemURL(_ id: UUID?) -> URL? {
        guard let id else { return nil }
        return model.groups.lazy.flatMap(\.items).first { $0.id == id }?.url
    }

    /// Moves the highlight through the files shown, in their current order.
    private func moveCurrent(_ step: Int) -> Bool {
        guard let gi = groupIndex, model.groups.indices.contains(gi) else { return false }
        let ids = sortedIDs(model.groups[gi])
        guard !ids.isEmpty else { return false }
        let i = currentItem.flatMap { ids.firstIndex(of: $0) } ?? (step > 0 ? -1 : ids.count)
        currentItem = ids[min(max(i + step, 0), ids.count - 1)]
        if preview != nil { preview = itemURL(currentItem) }
        return true
    }

    /// An installed app and its files are ticked together: its data (logins, settings, chats)
    /// only ever goes as part of uninstalling it, never on its own, so an app you keep can't be
    /// signed out or reset by a cleanup.
    private func itemBinding(_ gi: Int, _ ii: Int) -> Binding<CleanItem> {
        Binding(get: { model.groups[gi].items[ii] }, set: { new in
            let toggled = model.groups[gi].items[ii].selected != new.selected
            model.groups[gi].items[ii] = new
            if toggled, model.groups[gi].section == "Apps" { setGroup(model.groups[gi].id, new.selected) }
        })
    }

    private func setGroup(_ id: UUID, _ on: Bool) {
        guard let gi = model.groups.firstIndex(where: { $0.id == id }) else { return }
        for ii in model.groups[gi].items.indices { model.groups[gi].items[ii].selected = on }
    }
}

/// One file in a review list. Clicking highlights it (Space or a double-click previews it);
/// only the circle selects it for removal.
struct ItemRow: View {
    @Binding var item: CleanItem
    let accent: Color
    var fallback = "doc"
    /// The highlighted row, the one Space previews.
    var isCurrent = false
    var onClick: () -> Void = {}
    var onHover: (Bool) -> Void = { _ in }
    var onPreview: () -> Void = {}
    @State private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            CheckBox(state: item.selected ? .on : .off, color: accent) { item.selected.toggle() }
            FileIcon(path: item.iconPath ?? item.url.path, fallback: fallback, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.body.weight(.medium)).lineLimit(1)
                Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if let d = item.date {
                Text(d.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .trailing)
            }
            Text(FS.format(item.size)).font(.callout.monospacedDigit()).frame(width: 80, alignment: .trailing)
            Button { FS.reveal(item.url) } label: { Image(systemName: "magnifyingglass") }
                .buttonStyle(.plain).foregroundStyle(.secondary).help(L("Show in Finder")).opacity(hover || isCurrent ? 1 : 0.4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.ink.opacity(isCurrent ? 0.11 : hover ? 0.05 : 0)))
        .contentShape(Rectangle())
        .onHover { hover = $0; onHover($0) }
        .onTapGesture(count: 2) { onClick(); onPreview() }
        .onTapGesture { onClick() }
        .contextMenu {
            Button(L("Quick Look")) { onClick(); onPreview() }
            Button(L("Show in Finder")) { FS.reveal(item.url) }
            Button(L("Copy Path")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            }
            Divider()
            Button(item.selected ? L("Deselect") : L("Select")) { item.selected.toggle() }
        }
    }
}
