import AppKit
import SwiftUI

/// Misty blue light, black ink, lens glass. Rounded light type for numbers and titles,
/// small tracked monospace labels for the Swiss grid.
enum Theme {
    static let ink = Color(red: 0.09, green: 0.09, blue: 0.085)
    static let paper = Color(red: 0.965, green: 0.95, blue: 0.925)
    static let beige = Color(red: 0.91, green: 0.885, blue: 0.84)
    static let beigeDeep = Color(red: 0.83, green: 0.795, blue: 0.735)
    static let good = Color(red: 0.36, green: 0.46, blue: 0.31)
    /// "White Grape" #B9C798.
    static let grape = Color(red: 185 / 255, green: 199 / 255, blue: 152 / 255)
    /// Pantone 15-5519 TCX "Turquoise" (#45B5AA) with the saturation turned down to #5DACA4,
    /// the Mac Health tint when all is well.
    static let turquoise = Color(red: 93 / 255, green: 172 / 255, blue: 164 / 255)
    static let bad = Color(red: 0.68, green: 0.27, blue: 0.21)
    static let warn = Color(red: 0.70, green: 0.51, blue: 0.20)

    static func display(_ size: CGFloat, _ weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight)
    }

    /// Caps lettering for titles, sidebar and buttons, like the logo's "MAC CARE".
    static func caps(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat = 10.5) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

/// Small uppercase monospace label, e.g. "01 — OVERVIEW".
struct SwissLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(Theme.mono()).tracking(2.2).foregroundStyle(Theme.ink.opacity(0.45))
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(Theme.ink.opacity(0.12)).frame(height: 0.5) }
}

/// Misty blue background with a blurred turquoise glow, like out-of-focus light, plus fine grain.
/// The two looks, switched with the sun and moon at the bottom of the sidebar.
enum Appearance: String {
    /// Misty blue and turquoise backdrop.
    case light
    /// See-through: the desktop shows through, blurred and milky.
    case glass
    static let key = "cln.appearance"
}

/// macOS's behind-window blur: what's under the window, blurred. The system material lays its
/// own milky fill and tone over the blur, which makes it far more opaque than wanted, so those
/// two layers are switched off and only the blur is kept.
struct BehindWindowBlur: NSViewRepresentable {
    final class ClearBlurView: NSVisualEffectView {
        private var watchers: [NSObjectProtocol] = []

        override func layout() { super.layout(); clearTint() }
        override func updateLayer() { super.updateLayer(); clearTint() }
        override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); clearTint() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            watchers.forEach(NotificationCenter.default.removeObserver)
            watchers = []
            guard let window else { return }
            // macOS rebuilds the material (and its milky layers) as the window settles, gains or
            // loses focus, or moves screens; clear it again each time.
            let names: [Notification.Name] = [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                                              NSWindow.didChangeScreenNotification, NSWindow.didResizeNotification,
                                              NSWindow.didDeminiaturizeNotification]
            watchers = names.map {
                NotificationCenter.default.addObserver(forName: $0, object: window, queue: .main) { [weak self] _ in self?.clearTint() }
            }
            clearTint()
            for delay in [0.05, 0.3, 1.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.clearTint() }
            }
        }

        deinit { watchers.forEach(NotificationCenter.default.removeObserver) }

        private func clearTint() {
            func walk(_ l: CALayer) {
                if ["fill", "tone", "Chameleon"].contains(l.name ?? "") {
                    l.isHidden = true
                    l.opacity = 0
                }
                l.sublayers?.forEach(walk)
            }
            if let layer { walk(layer) }
        }
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = ClearBlurView()
        v.blendingMode = .behindWindow
        v.material = .fullScreenUI
        v.state = .active
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

struct Backdrop: View {
    var accent: Color = Theme.ink
    @AppStorage(Appearance.key) private var appearance = Appearance.light.rawValue

    var body: some View {
        if appearance == Appearance.glass.rawValue {
            ZStack {
                BehindWindowBlur()
                // a 20% light grey layer over the blurred desktop
                Color(white: 0.85).opacity(0.20)
                Image(nsImage: Grain.image).resizable(resizingMode: .tile).opacity(0.06).blendMode(.overlay)
            }
            .ignoresSafeArea()
        } else {
            misty
        }
    }

    private var misty: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.60, green: 0.72, blue: 0.84), Color(red: 0.77, green: 0.83, blue: 0.88),
                                    Color(red: 0.86, green: 0.88, blue: 0.89)], startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { g in
                Ellipse()
                    .fill(RadialGradient(colors: [Color(red: 0.24, green: 0.47, blue: 0.56).opacity(0.85),
                                                  Color(red: 0.36, green: 0.58, blue: 0.66).opacity(0.45), .clear],
                                         center: .center, startRadius: 0, endRadius: max(g.size.width, g.size.height) * 0.45))
                    .frame(width: g.size.width * 0.9, height: g.size.height * 1.05)
                    .position(x: g.size.width * 0.58, y: g.size.height * 0.62)
                    .blur(radius: 60)
            }
            Image(nsImage: Grain.image).resizable(resizingMode: .tile).opacity(0.08).blendMode(.overlay)
        }
        .ignoresSafeArea()
    }
}

/// A small tile of random noise, repeated over the background for a film-grain texture.
enum Grain {
    static let image: NSImage = {
        let n = 192
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n, bitsPerSample: 8,
                                   samplesPerPixel: 2, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceWhite,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        for y in 0..<n {
            for x in 0..<n {
                var px = [Int.random(in: 0...255), 255]
                rep.setPixel(&px, atX: x, y: y)
            }
        }
        let img = NSImage(size: NSSize(width: n, height: n))
        img.addRepresentation(rep)
        return img
    }()
}

/// Liquid glass measured from the reference toggle, translated to CLN's light blue backdrop.
/// The body is clear: at the top it is the backdrop itself (about 4% toward white), and light
/// pools toward the bottom (about 24% toward white). Under the top rim sits a faint shadow band.
/// The rim changes all the way round, as measured: a pure white line along the bottom, a pale
/// turquoise-white line along the top, both fading out through the corners, and a rim darker
/// than the glass on the left and right ends (more so on the right). A fine dark hairline runs
/// around the outside. `knob` is the selected pill: a step darker than the track, still lighter
/// at the bottom, with only a soft lower rim.
struct LiquidGlass<S: InsettableShape>: View {
    let shape: S
    var knob = false
    var pressed = false
    /// Thickness of the rim lights; buttons use less than large panels.
    var rim: CGFloat = 1.5
    /// Corner radius of `shape`, so the rim lights turn the corners where the shape does.
    /// nil = a capsule (half the height).
    var corner: CGFloat? = nil
    /// Colour laid over the body; the Scan buttons use 25% white.
    var tint: Color = .clear
    private let deep = Color(red: 0.06, green: 0.20, blue: 0.26)
    private let shade = Color(red: 0.03, green: 0.12, blue: 0.16)
    private let topLight = Color(red: 0.88, green: 0.97, blue: 1.0)

    var body: some View {
        GeometryReader { geo in
            let h = max(geo.size.height, 1)
            let r = min(corner ?? h / 2, h / 2)
            // Positions measured in the reference's round ends, as a share of the corner:
            // 0 = the flat edge, 1 = halfway down the side.
            let top = { (k: CGFloat) in min(0.5, k * r / h) }
            let bottom = { (k: CGFloat) in max(0.5, 1 - k * r / h) }
            ZStack {
                if knob {
                    shape.fill(LinearGradient(stops: [.init(color: deep.opacity(0.16), location: 0),
                                                      .init(color: deep.opacity(0.10), location: 0.5),
                                                      .init(color: deep.opacity(0.03), location: 1)],
                                              startPoint: .top, endPoint: .bottom))
                    shape.stroke(Color.black.opacity(0.10), lineWidth: 6).blur(radius: 4).offset(y: 3).mask(shape)
                    shape.strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                        .mask(LinearGradient(stops: [.init(color: .clear, location: bottom(0.5)), .init(color: .white, location: 1)],
                                             startPoint: .top, endPoint: .bottom))
                } else {
                    shape.fill(tint)
                    // light pooling toward the bottom
                    shape.fill(LinearGradient(stops: [.init(color: .white.opacity(pressed ? 0.02 : 0.04), location: 0),
                                                      .init(color: .white.opacity(0.09), location: 0.45),
                                                      .init(color: .white.opacity(0.17), location: 0.8),
                                                      .init(color: .white.opacity(pressed ? 0.16 : 0.26), location: 1)],
                                              startPoint: .top, endPoint: .bottom))
                    // faint shadow band just under the top rim
                    shape.stroke(shade.opacity(pressed ? 0.14 : 0.08), lineWidth: 8)
                        .blur(radius: 5).offset(y: 4).mask(shape)
                    // rim lights: top and bottom bright, fading through the corners
                    shape.strokeBorder(LinearGradient(stops: [
                        .init(color: topLight.opacity(0.70), location: 0),
                        .init(color: topLight.opacity(0.60), location: top(0.14)),
                        .init(color: topLight.opacity(0.38), location: top(0.29)),
                        .init(color: topLight.opacity(0.20), location: top(0.5)),
                        .init(color: topLight.opacity(0.05), location: top(0.74)),
                        .init(color: .white.opacity(0), location: top(1)),
                        .init(color: .white.opacity(0), location: bottom(0.5)),
                        .init(color: .white.opacity(0.32), location: bottom(0.29)),
                        .init(color: .white.opacity(0.70), location: bottom(0.13)),
                        .init(color: .white.opacity(0.98), location: bottom(0.03)),
                        .init(color: .white.opacity(0.98), location: 1),
                    ], startPoint: .top, endPoint: .bottom), lineWidth: rim)
                    // darker rim on the left and right ends, strongest on the right
                    shape.strokeBorder(shade.opacity(pressed ? 0.26 : 0.20), lineWidth: rim)
                        .mask(LinearGradient(stops: [.init(color: .clear, location: top(0.6)),
                                                     .init(color: .white, location: top(1)),
                                                     .init(color: .white, location: bottom(0.74)),
                                                     .init(color: .clear, location: bottom(0.45))],
                                             startPoint: .top, endPoint: .bottom))
                        .mask(LinearGradient(colors: [.white.opacity(0.55), .white], startPoint: .leading, endPoint: .trailing))
                }
                // fine dark hairline around the outside
                shape.inset(by: -0.75).stroke(shade.opacity(knob ? 0.06 : 0.16), lineWidth: 0.9)
            }
        }
        .compositingGroup()
        .shadow(color: shade.opacity(knob ? 0 : (pressed ? 0.08 : 0.16)),
                radius: pressed ? 6 : 14, y: pressed ? 3 : 8)
    }
}

/// Cards and panels; `concave` gives the button glass.
struct MilkGlass<S: InsettableShape>: View {
    let shape: S
    var concave = false
    var pressed = false

    var body: some View {
        if concave { LensGlass(shape: shape, pressed: pressed) } else { LiquidGlass(shape: shape, rim: 1.5, corner: 22) }
    }
}

/// Glass for buttons.
struct LensGlass<S: InsettableShape>: View {
    let shape: S
    var depth: Double = 1
    var pressed = false
    /// Colour laid over the glass; the Scan buttons use 25% white.
    var tint: Color = .clear

    var body: some View { LiquidGlass(shape: shape, pressed: pressed, rim: depth > 1 ? 1.4 : 1.2, tint: tint) }
}

/// Main actions (a slightly heavier bottom light) and, with `knob`, the current selection.
struct InkGlass<S: InsettableShape>: View {
    let shape: S
    var pressed = false
    var knob = false
    var tint: Color = .clear

    var body: some View {
        if knob { LiquidGlass(shape: shape, knob: true) } else { LensGlass(shape: shape, depth: 1.45, pressed: pressed, tint: tint) }
    }
}

extension View {
    /// Lettering and glyphs on lens glass: black ink.
    func embossed() -> some View {
        self.foregroundStyle(Theme.ink)
    }
}

/// Segmented control: a liquid glass track; the chosen option sits in a darker knob.
struct GlassSegmented<T: Hashable>: View {
    @Binding var selection: T
    let options: [(value: T, label: String)]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let on = option.value == selection
                Button { withAnimation(.quick(0.25)) { selection = option.value } } label: {
                    Text(option.label.uppercased())
                        .font(Theme.caps(10.5, on ? .semibold : .medium))
                        .tracking(0.6)
                        .foregroundStyle(Theme.ink.opacity(on ? 1 : 0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background { if on { InkGlass(shape: Capsule(), knob: true) } }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(LensGlass(shape: Capsule()))
    }
}

extension View {
    func glassCard(radius: CGFloat = 22, padding: CGFloat = 20) -> some View {
        self.padding(padding)
            .background(MilkGlass(shape: RoundedRectangle(cornerRadius: radius, style: .continuous)))
    }
}

/// Large: milk-glass lens capsule. Small: solid ink capsule.
struct PillButtonStyle: ButtonStyle {
    var color: Color = Theme.ink
    var large = false
    /// The Scan buttons: 25% whiter glass so they stand out.
    var scan = false

    func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, large: large, scan: scan)
    }

    private struct PillBody: View {
        let configuration: ButtonStyleConfiguration
        let large: Bool
        let scan: Bool
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            Group {
                if large {
                    configuration.label
                        .font(Theme.caps(15))
                        .textCase(.uppercase)
                        .compatTracking(1.6)
                        .embossed()
                        .padding(.horizontal, 44)
                        .padding(.vertical, 18)
                        .background(InkGlass(shape: Capsule(), pressed: configuration.isPressed, tint: scan ? .white.opacity(0.25) : .clear))
                } else {
                    configuration.label
                        .font(Theme.caps(10.5))
                        .textCase(.uppercase)
                        .compatTracking(0.8)
                        .lineLimit(1)
                        .fixedSize()
                        .embossed()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(InkGlass(shape: Capsule(), pressed: configuration.isPressed, tint: scan ? .white.opacity(0.25) : .clear))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(enabled ? 1 : 0.35)
            .contentShape(Capsule())
        }
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GhostBody(configuration: configuration)
    }

    private struct GhostBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .font(Theme.caps(11.5))
                .textCase(.uppercase)
                .compatTracking(1)
                .embossed()
                .padding(.horizontal, 15)
                .padding(.vertical, 7)
                .background(MilkGlass(shape: Capsule(), concave: true, pressed: configuration.isPressed))
                .opacity(enabled ? 1 : 0.35)
                .contentShape(Capsule())
        }
    }
}

struct CheckBox: View {
    let state: CheckState
    var color: Color = Theme.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if state == .off {
                    Circle().strokeBorder(Theme.ink.opacity(0.35), lineWidth: 1.2)
                } else {
                    Circle().fill(Theme.ink)
                    Image(systemName: state == .on ? "checkmark" : "minus")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.paper)
                }
            }
            .frame(width: 18, height: 18)
            .padding(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Round milk-glass lens with a thin ink glyph.
struct IconTile: View {
    let symbol: String
    var color: Color = Theme.ink
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.40, weight: .light))
            .embossed()
            .frame(width: size, height: size)
            .background(MilkGlass(shape: Circle(), concave: true))
    }
}

struct FileIcon: View {
    let path: String?
    var fallback: String = "doc"
    var size: CGFloat = 28

    var body: some View {
        if let path {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: fallback)
                .font(.system(size: size * 0.55, weight: .light))
                .foregroundStyle(Theme.ink.opacity(0.6))
                .frame(width: size, height: size)
        }
    }
}

/// "LAST CLEANED · 19 NOV 2026, 10:34 · 7 MINUTES AGO", shown on every screen.
struct LastCleanedLabel: View {
    @EnvironmentObject private var activity: ActivityStore
    let key: String
    var prefix = "Last cleaned"

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(activity.lastCleaned(key) == nil ? Theme.ink.opacity(0.25) : Theme.ink).frame(width: 5, height: 5)
            Text(text.uppercased()).font(Theme.mono(10)).tracking(1.4).foregroundStyle(Theme.ink.opacity(0.55))
        }
    }

    private var text: String {
        guard let d = activity.lastCleaned(key) else { return "\(L(prefix)) · \(L("never"))" }
        return "\(L(prefix)) · \(d.formatted(date: .abbreviated, time: .shortened)) · \(FS.relative(d))"
    }
}

/// Four-point star with concave sides and long, thin rays.
struct Sparkle: Shape {
    var waist: CGFloat = 0.07

    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let w = min(r.width, r.height) / 2 * waist
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: c.y), control: CGPoint(x: c.x + w, y: c.y - w))
        p.addQuadCurve(to: CGPoint(x: c.x, y: r.maxY), control: CGPoint(x: c.x + w, y: c.y + w))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: c.y), control: CGPoint(x: c.x - w, y: c.y + w))
        p.addQuadCurve(to: CGPoint(x: c.x, y: r.minY), control: CGPoint(x: c.x - w, y: c.y - w))
        p.closeSubpath()
        return p
    }
}

/// The CLN wordmark, same proportions as the app icon (H = cap height of CLN):
/// sparkle centered on the C's top-left corner with radius 0.25H; "MAC CARE" in spaced
/// mono, its top 0.43H below the CLN baseline, starting 0.09H in from the C.
struct CLNLogo: View {
    var size: CGFloat = 50

    var body: some View {
        let font = NSFont(name: "Helvetica-Bold", size: size) ?? .boldSystemFont(ofSize: size)
        let H = font.capHeight
        let r = H * 0.25
        let bearing = size * 0.035
        let monoSize = max(9, H * 0.14 / 0.70)
        let mono = NSFont.monospacedSystemFont(ofSize: monoSize, weight: .medium)
        // Text frames run from ascender to descender, so convert the gaps to frame offsets.
        let capTopInFrame = font.ascender - H
        let labelTop = 0.43 * H + font.descender - (mono.ascender - mono.capHeight)

        VStack(alignment: .leading, spacing: 0) {
            Text("CLN")
                .font(.custom("Helvetica-Bold", size: size))
                .tracking(-size * 0.055)
                .foregroundStyle(Theme.ink)
                .overlay(alignment: .topLeading) {
                    Sparkle()
                        .fill(Theme.ink)
                        .frame(width: r * 2, height: r * 2)
                        .offset(x: bearing - r, y: capTopInFrame - r)
                }
            HStack(spacing: monoSize * 0.9) {
                Text("MAC CARE")
                    .font(.system(size: monoSize, weight: .medium, design: .monospaced))
                    .tracking(monoSize * 0.42)
                    .foregroundStyle(Theme.ink.opacity(0.5))
                Text("v\(AppInfo.version)")
                    .font(.system(size: monoSize, weight: .medium, design: .monospaced))
                    .tracking(monoSize * 0.15)
                    .foregroundStyle(Theme.ink.opacity(0.32))
            }
            .padding(.leading, bearing + 0.09 * H)
                .padding(.top, max(0, labelTop))
        }
        .padding(.leading, max(0, r - bearing))
        .padding(.top, max(0, r - capTopInFrame))
    }
}
