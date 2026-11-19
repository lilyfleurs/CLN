import AppKit
import QuickLook
import SwiftUI

@MainActor
final class SpaceLensModel: ObservableObject {
    @Published var phase: Phase = .idle
    @Published var status = ""
    @Published var root: URL = FS.home
    @Published var current: SpaceNode?
    @Published var selected = Set<UUID>()
    @Published var lastResult: CleanResult?
    /// Bumped after removals so views redraw the mutated tree.
    @Published var revision = 0
    private var flag = CancelFlag()

    func scan() {
        phase = .scanning
        status = "Starting…"
        selected = []
        lastResult = nil
        ScanTicker.shared.reset()
        let f = CancelFlag()
        flag = f
        let root = root
        Task.detached(priority: .userInitiated) {
            let node = SpaceScanner.scan(root, cancel: f) { s in Task { @MainActor in self.status = s } }
            await MainActor.run {
                if f.isCancelled { self.phase = .idle; return }
                self.current = node
                self.phase = .results
            }
        }
    }

    func cancel() { flag.cancel() }

    var selectedNodes: [SpaceNode] { current?.children.filter { selected.contains($0.id) } ?? [] }

    func trashSelected(activity: ActivityStore) {
        guard let parent = current else { return }
        let nodes = selectedNodes
        let items = nodes.map { CleanItem(url: $0.url, name: $0.name, detail: "", size: $0.size) }
        let (r, moved) = FS.trash(items)
        for n in nodes where moved.contains(n.url) { parent.remove(n) }
        selected = []
        lastResult = r
        revision += 1
        activity.record(.personal, freed: r.freed, count: r.count, keys: [Module.spaceLens.rawValue])
        if r.count > 0 { activity.recordRun(); Chime.play() }
    }
}

struct SpaceLensView: View {
    @ObservedObject var model: SpaceLensModel
    @EnvironmentObject private var activity: ActivityStore
    @State private var confirm = false
    @State private var hovered: UUID?
    /// The highlighted item: clicked, not selected. Space previews it.
    @State private var current: UUID?
    @State private var preview: URL?
    @FocusState private var focused: Bool

    private let accent = Module.spaceLens.accent

    var body: some View {
        switch model.phase {
        case .idle, .finished:
            ModuleIntro(module: .spaceLens, accessory: { FolderPicker(root: $model.root, includeDisk: true) }, action: model.scan)
        case .scanning:
            ScanningView(module: .spaceLens, status: model.status, title: L("Mapping your storage…"),
                         expectedBytes: model.root.path == "/" ? DiskInfo.current().used : nil, onCancel: model.cancel)
        case .results:
            if let node = model.current { results(node) }
        }
    }

    private func results(_ node: SpaceNode) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { model.phase = .idle } label: { Label(L("Back"), systemImage: "chevron.left").font(Theme.display(15, .regular)) }
                    .buttonStyle(.plain).foregroundStyle(accent)
                breadcrumbs(node)
                Spacer()
                Button(L("Show in Finder")) { FS.reveal(node.url) }.buttonStyle(GhostButtonStyle())
                LastCleanedLabel(key: Module.spaceLens.rawValue)
            }
            if let r = model.lastResult { ResultBanner(result: r, accent: accent) { model.lastResult = nil } }
            HStack(spacing: 16) {
                treemap(node)
                list(node).frame(width: 360)
            }
            HStack {
                // Full path of whatever is under the pointer, so it can be found in Finder
                if let h = hoveredNode(node) {
                    Text(FS.tilde(h.url.path)).font(Theme.mono(11)).lineLimit(1).truncationMode(.middle)
                        .foregroundStyle(Theme.ink.opacity(0.7))
                    Text("· \(FS.format(h.size)) · \(L("Space to preview"))").font(Theme.mono(11)).foregroundStyle(Theme.ink.opacity(0.45))
                        .fixedSize()
                } else {
                    Text("\(FS.tilde(node.url.path)) · \(FS.format(node.size))").font(Theme.mono(11)).lineLimit(1)
                        .truncationMode(.middle).foregroundStyle(Theme.ink.opacity(0.7))
                }
                Spacer()
                Text(model.selected.isEmpty ? L("No items selected") :
                     L("%@ selected · %@", "\(model.selected.count)", FS.format(model.selectedNodes.reduce(0) { $0 + $1.size })))
                    .foregroundStyle(.secondary)
                Button(L("Move to Trash")) { confirm = true }
                    .buttonStyle(PillButtonStyle(color: accent))
                    .disabled(model.selected.isEmpty)
            }
        }
        .padding(24)
        .id(model.revision)
        .quickLookPreview($preview)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(.space) {
            // Like Finder: Space previews the item under the pointer, or the highlighted one
            if preview != nil { preview = nil; return .handled }
            let target = hoveredNode(node) ?? node.children.first { $0.id == current }
                ?? (model.selectedNodes.count == 1 ? model.selectedNodes.first : nil)
            guard let target else { return .ignored }
            preview = target.url
            return .handled
        }
        .alert(L("Move %@ items to the Trash?", "\(model.selected.count)"), isPresented: $confirm) {
            Button(L("Move to Trash"), role: .destructive) { model.trashSelected(activity: activity) }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(L("You can put them back from the Trash until you empty it.")
                 + (selectionHasAppData ? "\n\n" + L("Some of these are app data in your Library. Removing them can sign you out of apps or reset their settings.") : ""))
        }
    }

    private func breadcrumbs(_ node: SpaceNode) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(node.path) { p in
                    Button(p.url.path == "/" ? "Macintosh HD" : p.name) { model.current = p; model.selected = [] }
                        .buttonStyle(.plain)
                        .font(.callout.weight(p === node ? .semibold : .regular))
                        .foregroundStyle(p === node ? .primary : .secondary)
                    if p !== node { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary) }
                }
            }
        }
        .padding(.leading, 14)
    }

    /// Pebble map: one rounded glass cell per item, its area matching the space it takes.
    /// Items of at least 0.8% get their own cell (45 at most); everything smaller shares one,
    /// so no cell is too thin to see.
    private func treemap(_ node: SpaceNode) -> some View {
        GeometryReader { geo in
            let all = node.children.filter { $0.size > 0 }
            let floor = Double(all.reduce(0) { $0 + $1.size }) * 0.008
            let shown = Array(all.prefix(45).filter { Double($0.size) >= floor })
            let rest = all.dropFirst(shown.count).reduce(Int64(0)) { $0 + $1.size }
            let values = shown.map { Double($0.size) } + (rest > 0 ? [Double(rest)] : [])
            let cells = VoronoiTreemap.cached(node.url.path + "#\(model.revision)", values, in: CGRect(origin: .zero, size: geo.size))
            ZStack(alignment: .topLeading) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, child in
                    if cells.indices.contains(i), cells[i].count > 2 { cell(child, points: cells[i]) }
                }
                if rest > 0, let pts = cells.last, pts.count > 2 {
                    others(count: all.count - shown.count, size: rest, points: pts)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cell(_ child: SpaceNode, points: [CGPoint]) -> some View {
        let isSel = model.selected.contains(child.id)
        let shape = RoundedPolygon(points: points, radius: 22, inset: 3)
        let area = VoronoiTreemap.polygonArea(points)
        let c = VoronoiTreemap.centroid(points)
        return ZStack {
            if isSel {
                InkGlass(shape: shape, knob: true)
            } else {
                LiquidGlass(shape: shape, rim: 1.2, corner: 22)
                if hovered == child.id { shape.fill(.white.opacity(0.18)) }
            }
            if current == child.id { shape.strokeBorder(Theme.ink, lineWidth: 1.5) }
            cellLabel(name: child.name, size: child.size, area: area,
                      check: (model.selected.contains(child.id), { toggle(child) }))
                .position(c)
        }
        .contentShape(shape)
        .onHover { hovered = $0 ? child.id : nil }
        .onTapGesture(count: 2) { open(child) }
        .onTapGesture { current = child.id; focused = true }
        .contextMenu { menu(child) }
        .help("\(child.name) — \(FS.format(child.size))\(child.isDirectory ? "\n" + L("Double-click to open") : "")")
    }

    private func others(count: Int, size: Int64, points: [CGPoint]) -> some View {
        let shape = RoundedPolygon(points: points, radius: 22, inset: 3)
        return ZStack {
            shape.fill(Theme.ink.opacity(0.05))
            shape.strokeBorder(Theme.ink.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            cellLabel(name: L("%@ smaller items", "\(count)"), size: size, area: VoronoiTreemap.polygonArea(points), check: nil)
                .position(VoronoiTreemap.centroid(points))
        }
        .help(L("Smaller items, listed on the right"))
    }

    /// Name and size at the cell's centre, scaled to the cell, with the circle that selects it;
    /// hidden when there's no room (select those from the list or the right-click menu).
    @ViewBuilder private func cellLabel(name: String, size: Int64, area: Double, check: (Bool, () -> Void)?) -> some View {
        let side = sqrt(area)
        if side > 56 {
            VStack(spacing: 4) {
                if let check { CheckBox(state: check.0 ? .on : .off, color: accent, action: check.1) }
                VStack(spacing: 2) {
                    Text(name).font(Theme.caps(min(15, max(10, side / 14)), .semibold))
                        .lineLimit(2).multilineTextAlignment(.center).truncationMode(.middle)
                    Text(FS.format(size)).font(Theme.mono(min(11, max(9, side / 20)))).foregroundStyle(Theme.ink.opacity(0.55))
                }
                .allowsHitTesting(false)
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: side * 0.75)
        }
    }

    /// Double-click: folders open in the map, files open in Quick Look.
    private func open(_ n: SpaceNode) {
        current = n.id
        if n.isDirectory { model.current = n; model.selected = [] } else { preview = n.url }
    }

    private func list(_ node: SpaceNode) -> some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(node.children.prefix(500)) { child in
                    HStack(spacing: 10) {
                        CheckBox(state: model.selected.contains(child.id) ? .on : .off, color: accent) { toggle(child) }
                        FileIcon(path: child.url.path, size: 24)
                        Text(child.name).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(FS.format(child.size)).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                        if child.isDirectory {
                            Button { model.current = child; model.selected = [] } label: { Image(systemName: "chevron.right") }
                                .buttonStyle(.plain).foregroundStyle(accent)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.ink.opacity(current == child.id ? 0.11 : hovered == child.id ? 0.06 : 0)))
                    .contentShape(Rectangle())
                    .onHover { hovered = $0 ? child.id : nil }
                    .onTapGesture(count: 2) { open(child) }
                    .onTapGesture { current = child.id; focused = true }
                    .contextMenu { menu(child) }
                }
            }
        }
        .glassCard(radius: 16, padding: 8)
    }

    @ViewBuilder private func menu(_ n: SpaceNode) -> some View {
        Button(L("Quick Look")) { preview = n.url }
        Button(L("Show in Finder")) { FS.reveal(n.url) }
        Button(L("Open")) { NSWorkspace.shared.open(n.url) }
        if n.isDirectory {
            Button(L("Open in Disk Map")) { model.current = n; model.selected = [] }
        }
        Divider()
        Button(L("Copy Path")) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(n.url.path, forType: .string)
        }
        Divider()
        Button(model.selected.contains(n.id) ? L("Deselect") : L("Select for Trash")) { toggle(n) }
    }

    /// Whether anything selected lives in ~/Library (app data, logins, settings).
    private var selectionHasAppData: Bool {
        let lib = FS.home.appendingPathComponent("Library").path + "/"
        return model.selectedNodes.contains { $0.url.path.hasPrefix(lib) || $0.url.path == String(lib.dropLast()) }
    }

    private func hoveredNode(_ node: SpaceNode) -> SpaceNode? {
        guard let hovered else { return nil }
        return node.children.first { $0.id == hovered }
    }

    private func toggle(_ n: SpaceNode) {
        if model.selected.contains(n.id) { model.selected.remove(n.id) } else { model.selected.insert(n.id) }
    }
}
