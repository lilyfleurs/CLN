import AppKit
import Foundation

/// A soft bell played once when a cleanup finishes. Synthesized (bell-like partials with a
/// slow exponential fade) so no audio file ships with the app.
enum Chime {
    private static var sound: NSSound?

    static func play() {
        if sound == nil, let s = NSSound(data: wav()) {
            s.volume = 0.35
            sound = s
        }
        sound?.stop()
        sound?.play()
    }

    private static func wav() -> Data {
        let rate = 44_100.0
        let seconds = 2.4
        let n = Int(rate * seconds)
        let base = 1046.5 // C6
        // (frequency ratio, amplitude, decay per second): a struck bell's inharmonic partials
        let partials: [(Double, Double, Double)] = [(1.0, 0.55, 2.2), (2.0, 0.22, 3.2), (2.76, 0.14, 4.5),
                                                    (5.40, 0.05, 7.0), (0.5, 0.10, 1.6)]
        var samples = [Int16](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / rate
            let attack = min(1, t / 0.006)
            var v = 0.0
            for (ratio, amp, decay) in partials {
                v += amp * exp(-decay * t) * sin(2 * .pi * base * ratio * t)
            }
            samples[i] = Int16(max(-1, min(1, v * attack * 0.8)) * 32_000)
        }

        var data = Data()
        func put<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        let byteCount = n * 2
        data.append(contentsOf: Array("RIFF".utf8)); put(UInt32(36 + byteCount))
        data.append(contentsOf: Array("WAVEfmt ".utf8)); put(UInt32(16)); put(UInt16(1)); put(UInt16(1))
        put(UInt32(rate)); put(UInt32(rate * 2)); put(UInt16(2)); put(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); put(UInt32(byteCount))
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}
