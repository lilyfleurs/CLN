// Draws CLN's app icon (black wordmark with a sparkle on a white tile with a soft turquoise glow) to a 1024px PNG.
// Usage: swift scripts/make_icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
let ink = NSColor(red: 0.09, green: 0.09, blue: 0.085, alpha: 1)

// Tile with drop shadow
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: NSColor.black.withAlphaComponent(0.28).cgColor)
NSColor(red: 0.90, green: 0.93, blue: 0.95, alpha: 1).setFill()
shape.fill()
ctx.restoreGState()

ctx.saveGState()
shape.addClip()
NSGradient(colors: [NSColor(red: 0.86, green: 0.91, blue: 0.94, alpha: 1),
                    NSColor(red: 0.93, green: 0.95, blue: 0.96, alpha: 1),
                    NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)])!.draw(in: shape, angle: -65)
// Blurred turquoise glow, like the app's background
NSGradient(colors: [NSColor(red: 0.45, green: 0.66, blue: 0.72, alpha: 0.38),
                    NSColor(red: 0.60, green: 0.75, blue: 0.80, alpha: 0.18),
                    NSColor(red: 0.45, green: 0.62, blue: 0.70, alpha: 0)])!
    .draw(in: shape, relativeCenterPosition: NSPoint(x: 0.08, y: -0.2))
// Milky sheen across the top
let sheen = NSBezierPath(ovalIn: NSRect(x: -80, y: 560, width: 1180, height: 640))
NSColor.white.withAlphaComponent(0.07).setFill()
sheen.fill()

ctx.restoreGState()

// Rim highlight
shape.lineWidth = 5
NSColor.white.withAlphaComponent(0.9).setStroke()
shape.stroke()

// Wordmark, laid out from the logo's proportions (H = cap height of CLN):
// sparkle centered on the C's top-left corner, radius 0.25H; MAC CARE cap height 0.14H,
// its top 0.43H below the CLN baseline, starting 0.09H in from the C. Whole group centered.
let font = NSFont(name: "Helvetica-Bold", size: 330) ?? .systemFont(ofSize: 330, weight: .heavy)
let word = NSAttributedString(string: "CLN", attributes: [.font: font, .foregroundColor: ink, .kern: -0.055 * 330])
let H = font.capHeight
let sr = H * 0.25
let bearing = 0.035 * font.pointSize
let mono = NSFont.monospacedSystemFont(ofSize: H * 0.14 / 0.70, weight: .medium)
let monoCap = mono.capHeight

let baseline = (1024 - 0.57 * H - sr + monoCap) / 2
let wordX = (1024 - bearing + sr - word.size().width) / 2
word.draw(at: NSPoint(x: wordX, y: baseline + font.descender))

let sc = NSPoint(x: wordX + bearing, y: baseline + H)
let sw: CGFloat = sr * 0.07
let spark = NSBezierPath()
spark.move(to: NSPoint(x: sc.x, y: sc.y + sr))
spark.curve(to: NSPoint(x: sc.x + sr, y: sc.y), controlPoint1: NSPoint(x: sc.x + sw, y: sc.y + sw), controlPoint2: NSPoint(x: sc.x + sw, y: sc.y + sw))
spark.curve(to: NSPoint(x: sc.x, y: sc.y - sr), controlPoint1: NSPoint(x: sc.x + sw, y: sc.y - sw), controlPoint2: NSPoint(x: sc.x + sw, y: sc.y - sw))
spark.curve(to: NSPoint(x: sc.x - sr, y: sc.y), controlPoint1: NSPoint(x: sc.x - sw, y: sc.y - sw), controlPoint2: NSPoint(x: sc.x - sw, y: sc.y - sw))
spark.curve(to: NSPoint(x: sc.x, y: sc.y + sr), controlPoint1: NSPoint(x: sc.x - sw, y: sc.y + sw), controlPoint2: NSPoint(x: sc.x - sw, y: sc.y + sw))
spark.close()
ink.setFill()
spark.fill()

let labelBaseline = baseline - 0.43 * H - monoCap
NSAttributedString(string: "MAC CARE", attributes: [.font: mono, .foregroundColor: ink.withAlphaComponent(0.6), .kern: mono.pointSize * 0.42])
    .draw(at: NSPoint(x: wordX + bearing + 0.09 * H, y: labelBaseline + mono.descender))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
