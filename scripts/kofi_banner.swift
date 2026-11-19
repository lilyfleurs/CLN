// Ko-fi social preview (2:1, 1200 x 600): the eye photo in a round glass lens on the misty
// blue and turquoise backdrop, bold caps type and the page address. No app name or logo.
// Usage: swift scripts/kofi_banner.swift <eye image> <output.png>
import AppKit
import SwiftUI

let args = CommandLine.arguments
let eye = NSImage(contentsOfFile: args[1])!
let out = URL(fileURLWithPath: args.count > 2 ? args[2] : "kofi-preview.png")
let ink = Color(red: 0.09, green: 0.09, blue: 0.085)
let shade = Color(red: 0.03, green: 0.12, blue: 0.16)

func grain() -> NSImage {
    let n = 192
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: n, pixelsHigh: n, bitsPerSample: 8, samplesPerPixel: 2,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceWhite, bytesPerRow: 0, bitsPerPixel: 0)!
    var seed: UInt64 = 42
    for y in 0..<n {
        for x in 0..<n {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            rep.setColor(NSColor(white: CGFloat(seed >> 56) / 255, alpha: 1), atX: x, y: y)
        }
    }
    let img = NSImage(size: NSSize(width: n, height: n))
    img.addRepresentation(rep)
    return img
}

struct Banner: View {
    var body: some View {
        ZStack {
            // misty blue backdrop with a blurred turquoise glow
            LinearGradient(colors: [Color(red: 0.60, green: 0.72, blue: 0.84), Color(red: 0.77, green: 0.83, blue: 0.88),
                                    Color(red: 0.86, green: 0.88, blue: 0.89)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Ellipse()
                .fill(RadialGradient(colors: [Color(red: 0.24, green: 0.47, blue: 0.56).opacity(0.85),
                                              Color(red: 0.36, green: 0.58, blue: 0.66).opacity(0.45), .clear],
                                     center: .center, startRadius: 0, endRadius: 520))
                .frame(width: 1100, height: 700)
                .position(x: 820, y: 360)
                .blur(radius: 60)
            Image(nsImage: grain()).resizable(resizingMode: .tile).opacity(0.08).blendMode(.overlay)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("A TIP KEEPS THINGS COMING")
                        .font(.system(size: 17, weight: .medium, design: .monospaced)).tracking(3.4)
                        .foregroundStyle(ink.opacity(0.5))
                    Text("SUPPORT\nLILYFLEURS")
                        .font(.system(size: 96, weight: .bold)).tracking(-1)
                        .lineSpacing(-14)
                        .foregroundStyle(ink)
                        .padding(.top, 22)
                    Spacer()
                    HStack(spacing: 16) {
                        Image(systemName: "cup.and.saucer")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(ink)
                            .frame(width: 58, height: 58)
                            .background(lens(Circle(), light: 0.9))
                        Text("ko-fi.com/lilyfleurs")
                            .font(.system(size: 30, weight: .regular, design: .monospaced))
                            .foregroundStyle(ink)
                    }
                }
                .padding(.vertical, 92)
                Spacer()
                // the eye, set in a round glass lens
                Image(nsImage: eye).resizable().scaledToFill()
                    .frame(width: 400, height: 400)
                    .clipShape(Circle())
                    .overlay(lens(Circle(), light: 1).allowsHitTesting(false))
                    .shadow(color: shade.opacity(0.25), radius: 30, y: 18)
            }
            .padding(.horizontal, 96)
        }
        .frame(width: 1200, height: 600)
    }

    /// The app's liquid glass: light pooling at the bottom, white bottom rim, pale top rim,
    /// darker sides and a fine dark hairline.
    func lens<S: InsettableShape>(_ shape: S, light: Double) -> some View {
        ZStack {
            shape.fill(LinearGradient(stops: [.init(color: .white.opacity(0.04 * light), location: 0),
                                              .init(color: .white.opacity(0.09 * light), location: 0.45),
                                              .init(color: .white.opacity(0.17 * light), location: 0.8),
                                              .init(color: .white.opacity(0.26 * light), location: 1)],
                                      startPoint: .top, endPoint: .bottom))
            shape.stroke(shade.opacity(0.10), lineWidth: 14).blur(radius: 10).offset(y: 8).mask(shape)
            shape.strokeBorder(LinearGradient(stops: [
                .init(color: Color(red: 0.88, green: 0.97, blue: 1).opacity(0.75), location: 0),
                .init(color: Color(red: 0.88, green: 0.97, blue: 1).opacity(0.3), location: 0.15),
                .init(color: .clear, location: 0.35),
                .init(color: .clear, location: 0.7),
                .init(color: .white.opacity(0.7), location: 0.9),
                .init(color: .white.opacity(0.98), location: 1),
            ], startPoint: .top, endPoint: .bottom), lineWidth: 3)
            shape.inset(by: -1).stroke(shade.opacity(0.18), lineWidth: 1.2)
        }
    }
}

MainActor.assumeIsolated {
    let r = ImageRenderer(content: Banner().environment(\.colorScheme, .light))
    r.scale = 1
    if let img = r.nsImage, let tiff = img.tiffRepresentation,
       let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
        try! png.write(to: out)
        print("wrote \(out.path)")
    }
}
