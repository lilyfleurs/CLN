import SwiftUI

/// Weighted Voronoi treemap: rounded, pebble-like cells whose areas match the sizes they stand
/// for. Built as a power diagram whose sites and weights are adjusted until every cell has its
/// share of the space (after Nocaj & Brandes).
enum VoronoiTreemap {
    /// Convex cell polygons for `values` (any order), filling `rect`.
    static func layout(_ values: [Double], in rect: CGRect, iterations: Int = 90) -> [[CGPoint]] {
        let n = values.count
        let total = values.reduce(0, +)
        guard n > 0, total > 0, rect.width > 1, rect.height > 1 else { return values.map { _ in [] } }
        if n == 1 { return [corners(rect)] }
        let area = Double(rect.width * rect.height)
        let target = values.map { max($0 / total, 0.002) * area }

        // Start from the squarified treemap so neighbours begin roughly where they end up.
        var sites = Treemap.layout(values, in: rect).enumerated().map { i, r -> CGPoint in
            // a little deterministic jitter keeps sites from lining up exactly
            let jx = CGFloat((i * 7919) % 13) - 6, jy = CGFloat((i * 104_729) % 11) - 5
            return CGPoint(x: min(max(r.midX + jx, rect.minX + 1), rect.maxX - 1), y: min(max(r.midY + jy, rect.minY + 1), rect.maxY - 1))
        }
        var weights = target.map { $0 * 0.05 }
        var cells: [[CGPoint]] = []

        for _ in 0..<iterations {
            cells = (0..<n).map { cell($0, sites, weights, rect) }
            let areas = cells.map(polygonArea)
            for i in 0..<n {
                if areas[i] > 1 { sites[i] = centroid(cells[i]) }
                let ratio = areas[i] > 1 ? target[i] / areas[i] : 2
                weights[i] = max(1, weights[i] * min(max(ratio, 0.5), 2))
            }
            // A site can't outweigh a neighbour by more than their squared distance, or the
            // neighbour's cell vanishes.
            for i in 0..<n {
                for j in 0..<n where i != j {
                    let d2 = Double(dist2(sites[i], sites[j]))
                    if weights[i] - weights[j] > d2 { weights[i] = weights[j] + d2 * 0.95 }
                }
            }
        }
        return (0..<n).map { tidy(cell($0, sites, weights, rect)) }
    }

    /// Drops corners closer than a pixel to the previous one and corners on a straight line.
    /// Clipping leaves both behind, and they break the rounded outline and the inset.
    static func tidy(_ poly: [CGPoint]) -> [CGPoint] {
        var p = poly
        var changed = true
        while changed, p.count > 3 {
            changed = false
            for k in p.indices {
                let prev = p[(k + p.count - 1) % p.count], cur = p[k], next = p[(k + 1) % p.count]
                let close = hypot(cur.x - prev.x, cur.y - prev.y) < 1
                let cross = (cur.x - prev.x) * (next.y - cur.y) - (cur.y - prev.y) * (next.x - cur.x)
                let straight = abs(cross) < 0.5 * hypot(cur.x - prev.x, cur.y - prev.y) * hypot(next.x - cur.x, next.y - cur.y) * 0.01
                if close || straight { p.remove(at: k); changed = true; break }
            }
        }
        return p.count > 2 ? p : []
    }

    private static func corners(_ r: CGRect) -> [CGPoint] {
        [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)]
    }

    /// The power cell of site i: the rectangle clipped by its bisector with every other site.
    private static func cell(_ i: Int, _ p: [CGPoint], _ w: [Double], _ rect: CGRect) -> [CGPoint] {
        var poly = corners(rect)
        let pi = p[i]
        for j in p.indices where j != i {
            let pj = p[j]
            // keep x where 2x·(pj − pi) ≤ |pj|² − |pi|² − wj + wi
            let a = CGPoint(x: 2 * (pj.x - pi.x), y: 2 * (pj.y - pi.y))
            let b = Double(pj.x * pj.x + pj.y * pj.y - pi.x * pi.x - pi.y * pi.y) - w[j] + w[i]
            poly = clip(poly, a, CGFloat(b))
            if poly.isEmpty { break }
        }
        return poly
    }

    /// Sutherland–Hodgman against the half-plane a·x ≤ b.
    private static func clip(_ poly: [CGPoint], _ a: CGPoint, _ b: CGFloat) -> [CGPoint] {
        var out: [CGPoint] = []
        for k in poly.indices {
            let s = poly[k], e = poly[(k + 1) % poly.count]
            let fs = a.x * s.x + a.y * s.y - b, fe = a.x * e.x + a.y * e.y - b
            if fs <= 0 { out.append(s) }
            if (fs < 0) != (fe < 0), fs != fe {
                let t = fs / (fs - fe)
                out.append(CGPoint(x: s.x + (e.x - s.x) * t, y: s.y + (e.y - s.y) * t))
            }
        }
        return out
    }

    static func polygonArea(_ p: [CGPoint]) -> Double {
        guard p.count > 2 else { return 0 }
        var s: CGFloat = 0
        for k in p.indices { let a = p[k], b = p[(k + 1) % p.count]; s += a.x * b.y - b.x * a.y }
        return Double(abs(s) / 2)
    }

    static func centroid(_ p: [CGPoint]) -> CGPoint {
        var cx: CGFloat = 0, cy: CGFloat = 0, s: CGFloat = 0
        for k in p.indices {
            let a = p[k], b = p[(k + 1) % p.count], c = a.x * b.y - b.x * a.y
            cx += (a.x + b.x) * c; cy += (a.y + b.y) * c; s += c
        }
        guard abs(s) > 0.0001 else { return p.first ?? .zero }
        return CGPoint(x: cx / (3 * s), y: cy / (3 * s))
    }

    private static func dist2(_ a: CGPoint, _ b: CGPoint) -> CGFloat { (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y) }

    // MARK: Cache

    /// Layouts by folder, size and item sizes, so hovering doesn't recompute them.
    @MainActor private static var cache: [String: [[CGPoint]]] = [:]

    @MainActor static func cached(_ key: String, _ values: [Double], in rect: CGRect) -> [[CGPoint]] {
        let k = "\(key)|\(Int(rect.width))x\(Int(rect.height))|\(values.map { Int($0) })"
        if let hit = cache[k] { return hit }
        if cache.count > 40 { cache.removeAll() }
        let cells = layout(values, in: rect)
        cache[k] = cells
        return cells
    }
}

/// A convex polygon with rounded corners, inset to leave a gap to its neighbours.
struct RoundedPolygon: InsettableShape {
    let points: [CGPoint]
    var radius: CGFloat = 18
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> RoundedPolygon {
        var s = self
        s.inset += amount
        return s
    }

    func path(in rect: CGRect) -> Path {
        let pts = Self.shrink(points, by: inset)
        var path = Path()
        guard pts.count > 2 else { return path }
        let n = pts.count
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        func len(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
        path.move(to: mid(pts[n - 1], pts[0]))
        for k in 0..<n {
            let cur = pts[k], next = pts[(k + 1) % n], prev = pts[(k + n - 1) % n]
            let r = min(radius, len(prev, cur) / 2, len(cur, next) / 2)
            path.addArc(tangent1End: cur, tangent2End: mid(cur, next), radius: r)
        }
        path.closeSubpath()
        return path
    }

    /// Moves every edge of a convex polygon inward by `d`.
    static func shrink(_ poly: [CGPoint], by d: CGFloat) -> [CGPoint] {
        let p = VoronoiTreemap.tidy(poly)
        guard d != 0, p.count > 2 else { return p }
        let n = p.count
        // orientation decides which side is inside
        var s: CGFloat = 0
        for k in 0..<n { let a = p[k], b = p[(k + 1) % n]; s += a.x * b.y - b.x * a.y }
        let sign: CGFloat = s > 0 ? 1 : -1
        var lines: [(CGPoint, CGPoint)] = []
        for k in 0..<n {
            let a = p[k], b = p[(k + 1) % n]
            let l = max(hypot(b.x - a.x, b.y - a.y), 0.0001)
            let nx = -(b.y - a.y) / l * sign * d, ny = (b.x - a.x) / l * sign * d
            lines.append((CGPoint(x: a.x + nx, y: a.y + ny), CGPoint(x: b.x + nx, y: b.y + ny)))
        }
        var out: [CGPoint] = []
        for k in 0..<n {
            let (a1, a2) = lines[(k + n - 1) % n], (b1, b2) = lines[k]
            let d1 = CGPoint(x: a2.x - a1.x, y: a2.y - a1.y), d2 = CGPoint(x: b2.x - b1.x, y: b2.y - b1.y)
            let den = d1.x * d2.y - d1.y * d2.x
            if abs(den) < 0.0001 { out.append(b1); continue }
            let t = ((b1.x - a1.x) * d2.y - (b1.y - a1.y) * d2.x) / den
            out.append(CGPoint(x: a1.x + d1.x * t, y: a1.y + d1.y * t))
        }
        // Too small to shrink that far (the polygon turned inside out): scale it down instead.
        let c0 = VoronoiTreemap.centroid(p), c1 = VoronoiTreemap.centroid(out)
        if VoronoiTreemap.polygonArea(out) > VoronoiTreemap.polygonArea(p) || hypot(c0.x - c1.x, c0.y - c1.y) > d * 2 {
            return p.map { CGPoint(x: c0.x + ($0.x - c0.x) * 0.8, y: c0.y + ($0.y - c0.y) * 0.8) }
        }
        return out
    }
}
