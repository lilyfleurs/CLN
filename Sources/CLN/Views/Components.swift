import AppKit
import SwiftUI

extension Module {
    var number: String { String(format: "%02d", (Module.allCases.firstIndex(of: self) ?? 0) + 1) }
}

struct ModuleIntro<Accessory: View>: View {
    let module: Module
    var actionTitle = "Scan"
    var lastLabel = "Last cleaned"
    @ViewBuilder let accessory: () -> Accessory
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 70) {
            // Big lens with the module glyph
            VStack(alignment: .leading, spacing: 18) {
                SwissLabel(text: "\(module.number) / 07")
                ZStack {
                    MilkGlass(shape: Circle(), concave: true)
                    Image(systemName: module.symbol)
                        .font(.system(size: 92, weight: .ultraLight))
                        .embossed()
                }
                .frame(width: 300, height: 300)
            }

            VStack(alignment: .leading, spacing: 0) {
                SwissLabel(text: "\(module.number) — \(module.title)")
                Text(module.title.uppercased()).font(Theme.caps(44, .bold)).tracking(1).foregroundStyle(Theme.ink).padding(.top, 12)
                Text(module.tagline).font(Theme.display(18)).foregroundStyle(Theme.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 6)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(module.features.enumerated()), id: \.element.title) { i, f in
                        Hairline()
                        HStack(spacing: 16) {
                            Text(String(format: "%02d", i + 1)).font(Theme.mono()).foregroundStyle(Theme.ink.opacity(0.4))
                            Text(f.title).font(Theme.display(17, .regular)).foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: f.symbol).font(.system(size: 13, weight: .light)).foregroundStyle(Theme.ink.opacity(0.5))
                        }
                        .padding(.vertical, 11)
                    }
                    Hairline()
                }
                .padding(.vertical, 22)

                accessory()
                LastCleanedLabel(key: module.rawValue, prefix: lastLabel).padding(.top, 14)
                Button(L(actionTitle), action: action)
                    .buttonStyle(PillButtonStyle(large: true, scan: true))
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, 22)
            }
            .frame(maxWidth: 470, alignment: .leading)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension ModuleIntro where Accessory == EmptyView {
    init(module: Module, actionTitle: String = "Scan", lastLabel: String = "Last cleaned", action: @escaping () -> Void) {
        self.init(module: module, actionTitle: actionTitle, lastLabel: lastLabel, accessory: { EmptyView() }, action: action)
    }
}

// MARK: - Scanning

/// Live scan screen: what's being looked at right now, plus line-art graphs.
struct ScanningView: View {
    let module: Module
    let status: String
    var title = L("Looking through your files")
    /// Total bytes the scan will cover, when known (e.g. the used space of a whole disk).
    var expectedBytes: Int64? = nil
    var onCancel: (() -> Void)?

    @State private var stages: [String] = []
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { tl in
            let tick = ScanTicker.shared.snapshot
            let t = tl.date.timeIntervalSince(start)
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        SwissLabel(text: "\(module.number) — \(L("Scanning")) \(module.title)")
                        Text((title + dots(t)).uppercased()).font(Theme.caps(30, .bold)).tracking(0.8).foregroundStyle(Theme.ink)
                    }
                    Spacer()
                    if let onCancel { Button(L("Stop"), action: onCancel).buttonStyle(GhostButtonStyle()) }
                }

                HStack(alignment: .top, spacing: 18) {
                    scoreCard(t: t, files: tick.files)
                    VStack(spacing: 18) {
                        examinedCard(bytes: tick.bytes)
                        elapsedCard(t: t)
                    }
                    .frame(width: 300)
                }

                // The file being looked at right now
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SwissLabel(text: L("Now scanning"))
                        Spacer()
                        SwissLabel(text: currentStage)
                    }
                    Text(tick.path.isEmpty ? L("Preparing…") : FS.tilde(tick.path))
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.ink.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .identityTransition()
                }
                .glassCard(radius: 18, padding: 18)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 20)
        }
        .onAppear { start = Date(); stages = [label(status)] }
        .whenChanged(status) { s in
            let l = label(s)
            if stages.last != l { stages.append(l) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var currentStage: String { stages.last ?? "" }

    private func label(_ s: String) -> String {
        var l = s.replacingOccurrences(of: "…", with: "")
        for p in ["Looking at ", "Looking for ", "Looking in ", "Checking ", "Measuring "] where l.hasPrefix(p) {
            l = String(l.dropFirst(p.count))
        }
        if let r = l.range(of: " · ") { l = String(l[..<r.lowerBound]) }
        return L(l.prefix(1).uppercased() + l.dropFirst())
    }

    private func dots(_ t: Double) -> String { String(repeating: ".", count: Int(t * 2) % 4) }

    /// The drive scanner, legend of stages on the right.
    private func scoreCard(t: Double, files: Int) -> some View {
        VStack(alignment: .leading) {
            Text(L("Scan")).font(Theme.display(22, .regular)).foregroundStyle(Theme.ink)
            HStack(alignment: .center, spacing: 10) {
                DriveScanHUD(t: t)
                    .opacity(0.8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(stages.suffix(6).enumerated()), id: \.offset) { i, s in
                        let current = s == stages.last
                        HStack(spacing: 8) {
                            Circle()
                                .fill(current ? Theme.ink : Theme.ink.opacity(0.3))
                                .frame(width: current ? 8 : 6, height: current ? 8 : 6)
                            Text(s).font(Theme.display(14, current ? .regular : .light))
                                .foregroundStyle(Theme.ink.opacity(current ? 0.9 : 0.45))
                                .lineLimit(1)
                        }
                    }
                }
                .frame(width: 190, alignment: .leading)
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(files.formatted()).font(Theme.display(50, .light)).foregroundStyle(Theme.ink)
                    .numericTransition()
                Text(L("files checked")).font(Theme.display(15)).foregroundStyle(Theme.ink.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
        .glassCard(radius: 30, padding: 26)
    }

    /// A line filling up from the left: the big dot glides right as data is read and reaches
    /// the end at the expected total (or eases toward it when the total isn't known).
    private func examinedCard(bytes: Int64) -> some View {
        let fraction: Double = {
            if let e = expectedBytes, e > 0 { return min(1, Double(bytes) / Double(e)) }
            return 1 - exp(-Double(bytes) / module.scanScale)
        }()
        let shown = (fraction * 300).rounded() / 300
        return VStack(alignment: .leading, spacing: 16) {
            Text(L("Examined")).font(Theme.display(15)).foregroundStyle(Theme.ink.opacity(0.6))
            GeometryReader { g in
                let travel = g.size.width - 34
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.14)).frame(height: 2)
                    Capsule().fill(Theme.ink).frame(width: max(4, travel * shown + 17), height: 2)
                    Circle().fill(Theme.ink).frame(width: 9, height: 9)
                    Rectangle().fill(Theme.ink.opacity(0.35)).frame(width: 1, height: 12).offset(x: g.size.width - 1)
                    Circle().fill(.white).overlay(Circle().stroke(Theme.ink.opacity(0.15)))
                        .shadow(color: Theme.ink.opacity(0.18), radius: 4, y: 2)
                        .frame(width: 34, height: 34)
                        .offset(x: travel * shown)
                }
                .frame(height: 36)
                .animation(.easeOut(duration: 1.8), value: shown)
            }
            .frame(height: 36)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(FS.format(bytes)).font(Theme.display(32)).foregroundStyle(Theme.ink).numericTransition()
                if let e = expectedBytes {
                    Text(L("of %@", FS.format(e))).font(Theme.display(14)).foregroundStyle(Theme.ink.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 26, padding: 20)
    }

    /// Nested half-arcs over a base line with an arrow, like a time-in-bed dial.
    private func elapsedCard(t: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Elapsed")).font(Theme.display(15)).foregroundStyle(Theme.ink.opacity(0.6))
            Canvas { ctx, size in
                let base = CGPoint(x: size.width / 2, y: size.height - 3)
                for i in 0..<4 {
                    var p = Path()
                    p.addArc(center: base, radius: 72 - CGFloat(i) * 14, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                    ctx.stroke(p, with: .color(Theme.ink.opacity(0.18)), lineWidth: 0.8)
                }
                // One sweep of the outer arc per minute
                let frac = min(1, t.truncatingRemainder(dividingBy: 60) / 60)
                if frac > 0.005 {
                    var sweep = Path()
                    sweep.addArc(center: base, radius: 72, startAngle: .degrees(180), endAngle: .degrees(180 + 180 * frac), clockwise: false)
                    ctx.stroke(sweep, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                var arrow = Path()
                arrow.move(to: CGPoint(x: base.x, y: base.y - 34)); arrow.addLine(to: CGPoint(x: base.x, y: base.y - 14))
                arrow.move(to: CGPoint(x: base.x - 5, y: base.y - 19)); arrow.addLine(to: CGPoint(x: base.x, y: base.y - 14))
                arrow.addLine(to: CGPoint(x: base.x + 5, y: base.y - 19))
                ctx.stroke(arrow, with: .color(Theme.ink.opacity(0.7)), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
                var line = Path()
                line.move(to: CGPoint(x: base.x - 100, y: base.y)); line.addLine(to: CGPoint(x: base.x + 100, y: base.y))
                ctx.stroke(line, with: .color(Theme.ink), lineWidth: 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            Text(elapsed(t)).font(Theme.display(32)).foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 26, padding: 20)
    }

    private func elapsed(_ t: Double) -> String {
        let s = Int(t)
        return s < 60 ? "\(s)s" : "\(s / 60)m \(s % 60)s"
    }
}

// MARK: - Results

/// Result of a cleanup: freed space plus anything that couldn't be removed.
struct ResultBanner: View {
    let result: CleanResult
    var accent: Color = Theme.ink
    var onClose: (() -> Void)?
    @State private var showFailures = false
    @State private var confirmEmpty = false
    /// nil until the user empties the Trash from here; then whether it worked.
    @State private var trashEmptied: Bool?
    /// Protected items still waiting after "Try Again" (nil = not retried yet).
    @State private var stillBlocked: [CleanItem]?
    @State private var retried: CleanResult?

    private var blocked: [CleanItem] { stillBlocked ?? result.blocked }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Circle().fill(result.failures.isEmpty ? Theme.good : Theme.warn).frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.count > 0 ? L("%@ freed · %@ items cleaned", FS.format(result.freed), "\(result.count)")
                                          : L("Nothing was cleaned")).font(Theme.display(16, .regular))
                    Text(result.failures.isEmpty ? L("Removed items are in the Trash if you need them back.")
                                                 : L("%@ items couldn't be removed.", "\(result.failures.count)"))
                        .font(Theme.display(13)).foregroundStyle(Theme.ink.opacity(0.55))
                }
                Spacer()
                // Suggest emptying the Trash: space is only really freed once it's emptied
                if result.count > 0 {
                    if let ok = trashEmptied {
                        Text(ok ? L("Trash emptied.") : L("Couldn't empty the Trash."))
                            .font(.caption).foregroundStyle(ok ? Theme.good : Theme.warn)
                    } else {
                        Button(L("Empty Trash")) { confirmEmpty = true }.buttonStyle(GhostButtonStyle())
                    }
                }
                if !result.failures.isEmpty {
                    Button(showFailures ? L("Hide") : L("Details")) { showFailures.toggle() }.buttonStyle(GhostButtonStyle())
                }
                if let onClose {
                    Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 11, weight: .light)) }
                        .buttonStyle(.plain).foregroundStyle(Theme.ink.opacity(0.5))
                }
            }
            if !blocked.isEmpty { accessFix }
            else if let r = retried, r.count > 0 {
                Text(L("Done: %@ more removed.", FS.format(r.freed))).font(.callout).foregroundStyle(Theme.good)
            }
            if showFailures {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(result.failures, id: \.self) { Text($0).font(Theme.mono(11)).foregroundStyle(Theme.ink.opacity(0.6)) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
            }
        }
        .foregroundStyle(Theme.ink)
        .glassCard(radius: 18, padding: 16)
        .onAppear { if result.blocked.isEmpty && !result.failures.isEmpty { showFailures = true } }
        .alert(L("Empty the Trash permanently?"), isPresented: $confirmEmpty) {
            Button(L("Empty Trash"), role: .destructive) {
                Task.detached {
                    let ok = FS.emptyTrash()
                    await MainActor.run {
                        trashEmptied = ok
                        if ok { Chime.play() }
                    }
                }
            }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(L("This permanently deletes everything in the Trash, including anything you put there yourself. It can't be undone."))
        }
    }
}

extension ResultBanner {
    /// What to do when macOS blocked some items: shown straight away, with the fix one click away.
    fileprivate var accessFix: some View {
        VStack(alignment: .leading, spacing: 10) {
            Hairline()
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield").font(.system(size: 20, weight: .light)).padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("%@ items need your permission", "\(blocked.count)")).font(Theme.display(14, .medium))
                    Text(L("macOS protects the data folders of other apps. To remove them: 1. Open Settings and turn on CLN under Full Disk Access. 2. Come back and click Try Again."))
                        .font(.callout).foregroundStyle(Theme.ink.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
                    Text(blocked.map(\.name).joined(separator: " · ")).font(Theme.mono(10)).foregroundStyle(Theme.ink.opacity(0.5)).lineLimit(2)
                }
            }
            HStack(spacing: 10) {
                Button(L("Open Settings")) { FS.openFullDiskAccessSettings() }.buttonStyle(PillButtonStyle())
                Button(L("Try Again")) { retry() }.buttonStyle(GhostButtonStyle())
                Button(L("Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting(blocked.map(\.url)) }
                    .buttonStyle(GhostButtonStyle())
            }
        }
    }

    fileprivate func retry() {
        let items = blocked
        Task.detached {
            let (r, _) = FS.trash(items)
            await MainActor.run {
                stillBlocked = r.blocked
                retried = r
                if r.count > 0 { Chime.play() }
            }
        }
    }
}

struct DoneView: View {
    let module: Module
    let result: CleanResult
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                MilkGlass(shape: Circle(), concave: true)
                Image(systemName: "checkmark").font(.system(size: 56, weight: .light)).embossed()
            }
            .frame(width: 150, height: 150)
            SwissLabel(text: "\(module.number) — \(module.title) · \(L("Complete"))")
            Text((result.count > 0 ? L("%@ freed", FS.format(result.freed)) : L("Nothing was removed")).uppercased())
                .font(Theme.caps(38, .bold)).tracking(1)
            LastCleanedLabel(key: module.rawValue)
            ResultBanner(result: result).frame(maxWidth: 560)
            Button(L("Done"), action: onDone).buttonStyle(PillButtonStyle(large: true))
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Menu to choose which folder a scan looks at.
struct FolderPicker: View {
    @Binding var root: URL
    var includeDisk = false

    var body: some View {
        Menu {
            Button(L("Home Folder")) { root = FS.home }
            ForEach(["Desktop", "Documents", "Downloads", "Movies", "Pictures"], id: \.self) { name in
                Button(L(name)) { root = FS.home.appendingPathComponent(name) }
            }
            if includeDisk {
                Divider()
                Button(L("Entire Disk (Macintosh HD)")) { root = URL(fileURLWithPath: "/") }
            }
            Divider()
            Button(L("Choose Folder…")) {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.directoryURL = root
                if panel.runModal() == .OK, let url = panel.url { root = url }
            }
        } label: {
            HStack(spacing: 12) {
                FileIcon(path: root.path, size: 22)
                VStack(alignment: .leading, spacing: 1) {
                    SwissLabel(text: L("Scan location"))
                    Text(root.path == "/" ? "Macintosh HD" : root == FS.home ? NSUserName() : root.lastPathComponent)
                        .font(Theme.display(16, .regular)).foregroundStyle(Theme.ink)
                }
                Spacer()
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .light)).foregroundStyle(Theme.ink.opacity(0.5))
            }
            .frame(width: 300)
            .glassCard(radius: 16, padding: 12)
        }
        .buttonMenuStyle()
        .buttonStyle(.plain)
        .fixedSize()
    }
}

/// Scanner HUD: a wireframe hard drive turning slowly in the middle, its platter spinning,
/// framed by crosshairs, corner brackets and rings, with a scan line passing
/// over it. The drive's dots light up turquoise where the scan line crosses them.
struct DriveScanHUD: View {
    let t: Double
    var label = L("Reading disk")

    private let ink = Theme.ink
    private let glow = Theme.turquoise

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let h = size.height
            grid(&ctx, size)
            rings(&ctx, c, h)
            crosshair(&ctx, size, c)
            // soft turquoise light under the drive
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - h * 0.34, y: c.y - h * 0.3, width: h * 0.68, height: h * 0.6)),
                     with: .radialGradient(Gradient(colors: [glow.opacity(0.28), glow.opacity(0)]), center: c,
                                           startRadius: 0, endRadius: h * 0.34))
            let box = CGRect(x: c.x - h * 0.3, y: c.y - h * 0.3, width: h * 0.6, height: h * 0.6)
            let scanY = box.minY + box.height * (0.5 + 0.5 * sin(t * 1.5))
            drive(&ctx, c, scale: h / 215, scanY: scanY)
            brackets(&ctx, box)
            // scan line with a glow band trailing it
            ctx.fill(Path(CGRect(x: box.minX - 10, y: scanY - 14, width: box.width + 20, height: 28)),
                     with: .linearGradient(Gradient(colors: [glow.opacity(0), glow.opacity(0.22), glow.opacity(0)]),
                                           startPoint: CGPoint(x: 0, y: scanY - 14), endPoint: CGPoint(x: 0, y: scanY + 14)))
            var line = Path(); line.move(to: CGPoint(x: box.minX - 10, y: scanY)); line.addLine(to: CGPoint(x: box.maxX + 10, y: scanY))
            ctx.stroke(line, with: .color(ink.opacity(0.55)), lineWidth: 0.8)
            labels(&ctx, c, h)
        }
    }

    // MARK: Frame

    private func grid(_ ctx: inout GraphicsContext, _ size: CGSize) {
        var dots = Path()
        for x in stride(from: CGFloat(6), to: size.width, by: 12) {
            for y in stride(from: CGFloat(6), to: size.height, by: 12) { dots.addRect(CGRect(x: x, y: y, width: 1, height: 1)) }
        }
        ctx.fill(dots, with: .color(ink.opacity(0.10)))
        // a few circuit-like traces toward the edges
        var traces = Path()
        for k in 0..<10 {
            let y = CGFloat(18 + (k * 37) % Int(max(size.height - 36, 1)))
            let left = k % 2 == 0, len = CGFloat(30 + (k * 23) % 60)
            let x0: CGFloat = left ? 0 : size.width, x1 = left ? len : size.width - len
            traces.move(to: CGPoint(x: x0, y: y)); traces.addLine(to: CGPoint(x: x1, y: y))
            traces.addLine(to: CGPoint(x: x1 + (left ? 8 : -8), y: y + 8))
        }
        ctx.stroke(traces, with: .color(ink.opacity(0.10)), lineWidth: 0.7)
    }

    private func rings(_ ctx: inout GraphicsContext, _ c: CGPoint, _ h: CGFloat) {
        for (r, o) in [(h * 0.47, 0.10), (h * 0.40, 0.07)] {
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(ink.opacity(o)), lineWidth: 0.8)
        }
        // slowly turning dashed ring and a radar sweep
        var dashed = Path()
        dashed.addArc(center: c, radius: h * 0.435, startAngle: .radians(t * 0.3), endAngle: .radians(t * 0.3 + .pi * 2), clockwise: false)
        ctx.stroke(dashed, with: .color(ink.opacity(0.22)), style: StrokeStyle(lineWidth: 1, dash: [2, 7]))
        for k in 0..<14 {
            var arc = Path()
            let a = t * 0.9 - Double(k) * 0.045
            arc.addArc(center: c, radius: h * 0.47, startAngle: .radians(a - 0.045), endAngle: .radians(a), clockwise: false)
            ctx.stroke(arc, with: .color(ink.opacity(0.5 * (1 - Double(k) / 14))), lineWidth: 2)
        }
    }

    private func crosshair(_ ctx: inout GraphicsContext, _ size: CGSize, _ c: CGPoint) {
        var p = Path()
        let gap = size.height * 0.36
        p.move(to: CGPoint(x: 14, y: c.y)); p.addLine(to: CGPoint(x: c.x - gap, y: c.y))
        p.move(to: CGPoint(x: c.x + gap, y: c.y)); p.addLine(to: CGPoint(x: size.width - 14, y: c.y))
        p.move(to: CGPoint(x: c.x, y: 0)); p.addLine(to: CGPoint(x: c.x, y: 16))
        p.move(to: CGPoint(x: c.x, y: size.height - 16)); p.addLine(to: CGPoint(x: c.x, y: size.height))
        ctx.stroke(p, with: .color(ink.opacity(0.35)), lineWidth: 0.8)
        // T-shaped ends and small squares, like a viewfinder
        var marks = Path()
        for x in [c.x - gap, c.x + gap] { marks.move(to: CGPoint(x: x, y: c.y - 7)); marks.addLine(to: CGPoint(x: x, y: c.y + 7)) }
        marks.move(to: CGPoint(x: c.x - 7, y: 16)); marks.addLine(to: CGPoint(x: c.x + 7, y: 16))
        marks.move(to: CGPoint(x: c.x - 7, y: size.height - 16)); marks.addLine(to: CGPoint(x: c.x + 7, y: size.height - 16))
        ctx.stroke(marks, with: .color(ink.opacity(0.7)), lineWidth: 1.4)
        for x in [CGFloat(30), size.width - 38] {
            for y in [c.y - 22, c.y + 14] { ctx.stroke(Path(CGRect(x: x, y: y, width: 8, height: 8)), with: .color(ink.opacity(0.3)), lineWidth: 0.8) }
        }
    }

    private func brackets(_ ctx: inout GraphicsContext, _ r: CGRect) {
        var p = Path()
        let l: CGFloat = 16
        for (x, y, dx, dy) in [(r.minX, r.minY, 1.0, 1.0), (r.maxX, r.minY, -1.0, 1.0), (r.minX, r.maxY, 1.0, -1.0), (r.maxX, r.maxY, -1.0, -1.0)] {
            p.move(to: CGPoint(x: x + l * dx, y: y)); p.addLine(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x, y: y + l * dy))
        }
        ctx.stroke(p, with: .color(ink.opacity(0.75)), style: StrokeStyle(lineWidth: 1.6, lineCap: .square))
    }

    private func labels(_ ctx: inout GraphicsContext, _ c: CGPoint, _ h: CGFloat) {
        func tag(_ s: String, y: CGFloat, blink: Bool) {
            let shown = s.uppercased() + (blink && Int(t * 2) % 2 == 0 ? " _" : "  ")
            let text = ctx.resolve(Text(shown).font(Theme.mono(9)).tracking(1.6).foregroundColor(ink.opacity(0.75)))
            let sz = text.measure(in: CGSize(width: 300, height: 20))
            let box = CGRect(x: c.x - sz.width / 2 - 6, y: y - sz.height / 2 - 3, width: sz.width + 12, height: sz.height + 6)
            ctx.stroke(Path(box), with: .color(ink.opacity(0.4)), lineWidth: 0.8)
            ctx.draw(text, at: CGPoint(x: c.x, y: y))
        }
        tag(L("Scan mode"), y: c.y - h * 0.4, blink: false)
        tag(label, y: c.y + h * 0.4, blink: true)
    }

    // MARK: Drive

    /// A 3.5" drive seen from above at an angle, turning gently left and right.
    private func drive(_ ctx: inout GraphicsContext, _ c: CGPoint, scale s: CGFloat, scanY: CGFloat) {
        let yaw = sin(t * 0.45) * 0.45
        let pitch = 0.95   // how far we look down onto it
        let H: Double = 14  // thickness
        func pt(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
            let x1 = x * cos(yaw) - z * sin(yaw), z1 = x * sin(yaw) + z * cos(yaw)
            return CGPoint(x: c.x + CGFloat(x1) * s, y: c.y + CGFloat(z1 * cos(pitch) - y * sin(pitch)) * s + 10 * s)
        }
        let W = 52.0, D = 72.0
        let corners = [(-W, -D), (W, -D), (W, D), (-W, D)]
        // case: bottom outline, top outline, vertical edges
        var box = Path()
        for y in [0.0, H] {
            box.move(to: pt(corners[0].0, y, corners[0].1))
            for k in 1...4 { let q = corners[k % 4]; box.addLine(to: pt(q.0, y, q.1)) }
        }
        for q in corners { box.move(to: pt(q.0, 0, q.1)); box.addLine(to: pt(q.0, H, q.1)) }
        ctx.stroke(box, with: .color(ink.opacity(0.55)), lineWidth: 0.9)
        // inner lid line and screws
        var lid = Path()
        let iw = W - 5, id = D - 5
        lid.move(to: pt(-iw, H, -id)); lid.addLine(to: pt(iw, H, -id)); lid.addLine(to: pt(iw, H, id)); lid.addLine(to: pt(-iw, H, id)); lid.closeSubpath()
        ctx.stroke(lid, with: .color(ink.opacity(0.22)), lineWidth: 0.7)
        for (x, z) in [(-W + 5, -D + 5), (W - 5, -D + 5), (W - 5, D - 5), (-W + 5, D - 5)] {
            let p = pt(x, H, z)
            ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 2.2, y: p.y - 1.6, width: 4.4, height: 3.2)), with: .color(ink.opacity(0.5)), lineWidth: 0.7)
        }
        // connector pins on the back edge
        var pins = Path()
        for k in 0..<14 { let x = -W + 10 + Double(k) * 4; pins.move(to: pt(x, 2, D)); pins.addLine(to: pt(x, 8, D)) }
        ctx.stroke(pins, with: .color(ink.opacity(0.4)), lineWidth: 0.7)

        // platter as a point cloud, spinning
        let pc = (0.0, -12.0), spin = t * 2.4
        for (ring, r) in [42.0, 36, 30, 24, 17, 10].enumerated() {
            let count = Int(r * 1.6)
            for k in 0..<count {
                let a = Double(k) / Double(count) * .pi * 2 + spin * (ring % 2 == 0 ? 1 : 0.8)
                let p = pt(pc.0 + cos(a) * r, H, pc.1 + sin(a) * r)
                let lit = abs(p.y - scanY) < 9
                let d: CGFloat = lit ? 2.4 : 1.4
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)),
                         with: .color(lit ? glow : ink.opacity(0.45)))
            }
        }
        // spindle
        var spindle = Path()
        for k in 0...24 {
            let a = Double(k) / 24 * .pi * 2
            let p = pt(pc.0 + cos(a) * 5, H, pc.1 + sin(a) * 5)
            if k == 0 { spindle.move(to: p) } else { spindle.addLine(to: p) }
        }
        ctx.stroke(spindle, with: .color(ink.opacity(0.7)), lineWidth: 1)
    }
}

extension Module {
    /// Rough size of a typical scan, so the Examined dot eases sensibly when the total isn't known.
    var scanScale: Double {
        switch self {
        case .overview, .cleanup, .activity: 4e9
        case .applications: 40e9
        case .performance: 1e6
        case .clutter, .spaceLens: 150e9
        }
    }
}
