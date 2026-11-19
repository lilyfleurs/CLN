// Renders a contact sheet of CLN logo concepts. Usage: swift scripts/logo_concepts.swift <out.png>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "concepts.png"
let W: CGFloat = 1950, H: CGFloat = 1420
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let ink = NSColor(red: 0.09, green: 0.09, blue: 0.085, alpha: 1)
let paper = NSColor(red: 0.965, green: 0.95, blue: 0.925, alpha: 1)
let beigeTop = NSColor(red: 0.93, green: 0.90, blue: 0.84, alpha: 1)
let beigeMid = NSColor(red: 0.86, green: 0.82, blue: 0.75, alpha: 1)
let beigeLow = NSColor(red: 0.77, green: 0.72, blue: 0.64, alpha: 1)

// Sheet background
NSGradient(colors: [paper, NSColor(red: 0.90, green: 0.875, blue: 0.83, alpha: 1)])!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -70)

func mono(_ s: String, _ size: CGFloat, _ p: NSPoint, alpha: CGFloat = 0.55, kern: CGFloat = 4) {
    NSAttributedString(string: s, attributes: [.font: NSFont.monospacedSystemFont(ofSize: size, weight: .medium),
                                               .foregroundColor: ink.withAlphaComponent(alpha), .kern: kern]).draw(at: p)
}

mono("CLN — LOGO CONCEPTS", 18, NSPoint(x: 70, y: H - 80), alpha: 0.6, kern: 6)
mono("V.01 · BEIGE / INK / MILK GLASS", 14, NSPoint(x: 70, y: H - 108), alpha: 0.4, kern: 4)

/// Four-point sparkle star.
func star(_ c: NSPoint, _ r: CGFloat, waist: CGFloat = 0.16) -> NSBezierPath {
    let p = NSBezierPath()
    let w = r * waist
    p.move(to: NSPoint(x: c.x, y: c.y + r))
    p.curve(to: NSPoint(x: c.x + r, y: c.y), controlPoint1: NSPoint(x: c.x + w, y: c.y + w), controlPoint2: NSPoint(x: c.x + w, y: c.y + w))
    p.curve(to: NSPoint(x: c.x, y: c.y - r), controlPoint1: NSPoint(x: c.x + w, y: c.y - w), controlPoint2: NSPoint(x: c.x + w, y: c.y - w))
    p.curve(to: NSPoint(x: c.x - r, y: c.y), controlPoint1: NSPoint(x: c.x - w, y: c.y - w), controlPoint2: NSPoint(x: c.x - w, y: c.y - w))
    p.curve(to: NSPoint(x: c.x, y: c.y + r), controlPoint1: NSPoint(x: c.x - w, y: c.y + w), controlPoint2: NSPoint(x: c.x - w, y: c.y + w))
    p.close()
    return p
}

func word(_ s: String, size: CGFloat, color: NSColor = ink) -> NSAttributedString {
    let f = NSFont(name: "Helvetica-Bold", size: size) ?? .systemFont(ofSize: size, weight: .heavy)
    return NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: color, .kern: -size * 0.055])
}

/// Glass lens like the app's buttons.
func lens(_ r: NSRect, arrow: Bool = true) {
    NSGradient(colors: [ink.withAlphaComponent(0.12), NSColor.white.withAlphaComponent(0.55)])!.draw(in: NSBezierPath(ovalIn: r), angle: -90)
    let rim = NSBezierPath(ovalIn: r.insetBy(dx: 1.5, dy: 1.5))
    rim.lineWidth = 3
    NSColor.white.withAlphaComponent(0.95).setStroke()
    rim.stroke()
    guard arrow else { return }
    let a = NSBezierPath()
    let cx = r.midX, cy = r.midY, s = r.width * 0.22
    a.move(to: NSPoint(x: cx, y: cy - s)); a.line(to: NSPoint(x: cx, y: cy + s))
    a.move(to: NSPoint(x: cx - s * 0.7, y: cy + s * 0.3)); a.line(to: NSPoint(x: cx, y: cy + s)); a.line(to: NSPoint(x: cx + s * 0.7, y: cy + s * 0.3))
    a.lineWidth = r.width * 0.035
    a.lineCapStyle = .round
    a.lineJoinStyle = .round
    ink.withAlphaComponent(0.75).setStroke()
    a.stroke()
}

/// Draws the beige milk-glass tile, then `content` clipped inside it. Tile is 500×500 at `o`.
func tile(_ o: NSPoint, title: String, note: String, _ content: (NSRect) -> Void) {
    let r = NSRect(x: o.x, y: o.y, width: 500, height: 500)
    let shape = NSBezierPath(roundedRect: r, xRadius: 112, yRadius: 112)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: NSColor.black.withAlphaComponent(0.22).cgColor)
    beigeMid.setFill(); shape.fill()
    ctx.restoreGState()
    ctx.saveGState()
    shape.addClip()
    NSGradient(colors: [beigeTop, beigeMid, beigeLow])!.draw(in: shape, angle: -65)
    NSColor.white.withAlphaComponent(0.14).setFill()
    NSBezierPath(ovalIn: NSRect(x: r.minX - 50, y: r.minY + 270, width: 600, height: 330)).fill()
    content(r)
    ctx.restoreGState()
    shape.lineWidth = 3
    NSColor.white.withAlphaComponent(0.9).setStroke()
    shape.stroke()
    mono(title, 17, NSPoint(x: o.x + 6, y: o.y - 46), alpha: 0.8, kern: 4)
    NSAttributedString(string: note, attributes: [.font: NSFont.systemFont(ofSize: 17, weight: .light),
                                                  .foregroundColor: ink.withAlphaComponent(0.55)])
        .draw(in: NSRect(x: o.x + 6, y: o.y - 100, width: 500, height: 48))
}

let cols: [CGFloat] = [100, 725, 1350]
let rows: [CGFloat] = [770, 160]

// A — Sparkle: current icon, with a just-polished star over the N
tile(NSPoint(x: cols[0], y: rows[0]), title: "A — SPARKLE", note: "Current icon plus a just-cleaned shine over the N.") { r in
    word("CLN", size: 165).draw(at: NSPoint(x: r.minX + 58, y: r.minY + 235))
    ink.setFill()
    star(NSPoint(x: r.minX + 420, y: r.minY + 430), 34).fill()
    star(NSPoint(x: r.minX + 455, y: r.minY + 380), 14).fill()
    mono("MAC CARE", 17, NSPoint(x: r.minX + 64, y: r.minY + 200), alpha: 0.5, kern: 5)
    lens(NSRect(x: r.minX + 300, y: r.minY + 60, width: 120, height: 120))
}

// B — Wiped: a diagonal glass band wiped across the L, with a squeegee
tile(NSPoint(x: cols[1], y: rows[0]), title: "B — WIPED", note: "A squeegee wipes a clear glass stripe through the L.") { r in
    let w = word("CLN", size: 165)
    let at = NSPoint(x: r.minX + 58, y: r.minY + 190)
    w.draw(at: at)
    let band = NSBezierPath()
    band.move(to: NSPoint(x: r.minX + 190, y: r.minY + 140))
    band.line(to: NSPoint(x: r.minX + 268, y: r.minY + 140))
    band.line(to: NSPoint(x: r.minX + 330, y: r.minY + 420))
    band.line(to: NSPoint(x: r.minX + 252, y: r.minY + 420))
    band.close()
    ctx.saveGState()
    band.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.85), NSColor.white.withAlphaComponent(0.35)])!.draw(in: band, angle: 75)
    word("CLN", size: 165, color: ink.withAlphaComponent(0.16)).draw(at: at)
    ctx.restoreGState()
    // squeegee at the bottom of the stripe
    let blade = NSBezierPath(roundedRect: NSRect(x: r.minX + 180, y: r.minY + 128, width: 98, height: 18), xRadius: 6, yRadius: 6)
    ink.setFill(); blade.fill()
    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: r.minX + 229, y: r.minY + 128)); handle.line(to: NSPoint(x: r.minX + 214, y: r.minY + 62))
    handle.lineWidth = 9; handle.lineCapStyle = .round; ink.setStroke(); handle.stroke()
    star(NSPoint(x: r.minX + 345, y: r.minY + 440), 20).fill()
    star(NSPoint(x: r.minX + 372, y: r.minY + 412), 9).fill()
}

// C — Star cut: a sparkle knocked out of the N (negative space)
tile(NSPoint(x: cols[2], y: rows[0]), title: "C — STAR CUT", note: "A sparkle cut out of the N, the way a polish catches light.") { r in
    word("CLN", size: 175).draw(at: NSPoint(x: r.minX + 48, y: r.minY + 175))
    beigeMid.setFill()
    star(NSPoint(x: r.minX + 326, y: r.minY + 282), 40, waist: 0.14).fill()
    ink.setFill()
    star(NSPoint(x: r.minX + 430, y: r.minY + 400), 18).fill()
    mono("MAC CARE", 17, NSPoint(x: r.minX + 56, y: r.minY + 120), alpha: 0.5, kern: 5)
}

// D — Sweep: bytes being swept off the N into a little trail
tile(NSPoint(x: cols[0], y: rows[1]), title: "D — SWEEP", note: "Little bytes get swept off the N and fly away.") { r in
    word("CLN", size: 165).draw(at: NSPoint(x: r.minX + 40, y: r.minY + 210))
    let squares: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(392, 228, 26, 1), (424, 262, 20, 0.75), (448, 300, 15, 0.55),
                                                           (466, 334, 11, 0.4), (478, 362, 8, 0.28)]
    for (x, y, s, a) in squares {
        ink.withAlphaComponent(a).setFill()
        NSBezierPath(roundedRect: NSRect(x: r.minX + x, y: r.minY + y, width: s, height: s), xRadius: s * 0.22, yRadius: s * 0.22).fill()
    }
    let swoosh = NSBezierPath()
    swoosh.move(to: NSPoint(x: r.minX + 60, y: r.minY + 175))
    swoosh.curve(to: NSPoint(x: r.minX + 430, y: r.minY + 200), controlPoint1: NSPoint(x: r.minX + 200, y: r.minY + 140), controlPoint2: NSPoint(x: r.minX + 340, y: r.minY + 150))
    swoosh.lineWidth = 7; swoosh.lineCapStyle = .round; ink.setStroke(); swoosh.stroke()
    mono("MAC CARE", 17, NSPoint(x: r.minX + 62, y: r.minY + 110), alpha: 0.5, kern: 5)
}

// E — Bubble: the C holds a soap bubble with a sparkle
tile(NSPoint(x: cols[1], y: rows[1]), title: "E — BUBBLE", note: "A soap bubble floats out of the C. Light and playful.") { r in
    word("CLN", size: 165).draw(at: NSPoint(x: r.minX + 58, y: r.minY + 190))
    for (x, y, d) in [(118.0, 268.0, 72.0), (190, 380, 44), (150, 430, 24)] as [(CGFloat, CGFloat, CGFloat)] {
        let b = NSRect(x: r.minX + x - d / 2, y: r.minY + y - d / 2, width: d, height: d)
        NSGradient(colors: [NSColor.white.withAlphaComponent(0.85), NSColor.white.withAlphaComponent(0.15)])!
            .draw(in: NSBezierPath(ovalIn: b), relativeCenterPosition: NSPoint(x: -0.4, y: 0.4))
        let rim = NSBezierPath(ovalIn: b); rim.lineWidth = 2.5
        ink.withAlphaComponent(0.55).setStroke(); rim.stroke()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: b.minX + d * 0.22, y: b.minY + d * 0.6, width: d * 0.2, height: d * 0.12)).fill()
    }
    ink.setFill()
    star(NSPoint(x: r.minX + 430, y: r.minY + 420), 24).fill()
    mono("MAC CARE", 17, NSPoint(x: r.minX + 64, y: r.minY + 150), alpha: 0.5, kern: 5)
}

// F — Lens star: the glass button itself becomes the sparkle
tile(NSPoint(x: cols[2], y: rows[1]), title: "F — LENS STAR", note: "Minimal: the glass button holds a star instead of an arrow.") { r in
    word("CLN", size: 165).draw(at: NSPoint(x: r.minX + 58, y: r.minY + 255))
    mono("MAC CARE", 17, NSPoint(x: r.minX + 64, y: r.minY + 220), alpha: 0.5, kern: 5)
    let l = NSRect(x: r.minX + 290, y: r.minY + 55, width: 150, height: 150)
    lens(l, arrow: false)
    ink.withAlphaComponent(0.85).setFill()
    star(NSPoint(x: l.midX, y: l.midY), 40).fill()
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
