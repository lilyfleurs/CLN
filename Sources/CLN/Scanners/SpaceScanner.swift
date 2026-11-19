import Foundation

final class SpaceNode: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    var size: Int64
    var children: [SpaceNode] = []
    let isDirectory: Bool
    weak var parent: SpaceNode?

    init(url: URL, size: Int64, isDirectory: Bool) {
        self.url = url
        self.name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        self.size = size
        self.isDirectory = isDirectory
    }

    var path: [SpaceNode] {
        var out: [SpaceNode] = [self]
        var n = parent
        while let p = n { out.insert(p, at: 0); n = p.parent }
        return out
    }

    func remove(_ child: SpaceNode) {
        children.removeAll { $0 === child }
        var n: SpaceNode? = self
        while let p = n { p.size -= child.size; n = p.parent }
    }
}

enum SpaceScanner {
    /// Paths that would double-count (other volumes, firmlinks) or are virtual.
    private static let skip: Set<String> = ["/Volumes", "/System/Volumes", "/dev", "/net", "/home", "/private/var/vm", "/cores"]
    private static let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey,
                                                    .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]

    static func scan(_ root: URL, cancel: CancelFlag, progress: @escaping (String) -> Void) -> SpaceNode {
        var count = 0
        return build(root, root: root, cancel: cancel, count: &count, progress: progress)
    }

    /// First folder under the scan root that `url` lives in, e.g. "Library".
    static func topFolder(_ url: URL, under root: URL) -> String {
        let rel = url.path.dropFirst(root.path == "/" ? 1 : root.path.count + 1)
        return rel.split(separator: "/").first.map(String.init) ?? root.lastPathComponent
    }

    private static func build(_ url: URL, root: URL, cancel: CancelFlag, count: inout Int, progress: (String) -> Void) -> SpaceNode {
        let node = SpaceNode(url: url, size: 0, isDirectory: true)
        guard let kids = try? FS.fm.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(keys), options: []) else { return node }
        for k in kids {
            if cancel.isCancelled { break }
            if skip.contains(k.path) { continue }
            guard let v = try? k.resourceValues(forKeys: keys), v.isSymbolicLink != true else { continue }
            let child: SpaceNode
            if v.isDirectory == true && v.isPackage != true {
                child = build(k, root: root, cancel: cancel, count: &count, progress: progress)
            } else {
                let size = v.isDirectory == true ? FS.size(of: k) : Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
                child = SpaceNode(url: k, size: size, isDirectory: false)
                if v.isDirectory != true { ScanTicker.shared.saw(k, size: size) }
                count += 1
                if count % 1000 == 0 { progress("\(topFolder(url, under: root)) · \(count.formatted()) items") }
            }
            child.parent = node
            node.size += child.size
            node.children.append(child)
        }
        node.children.sort { $0.size > $1.size }
        return node
    }
}

enum Treemap {
    /// Squarified treemap: rectangles for `values` (sorted descending) filling `rect`.
    static func layout(_ values: [Double], in rect: CGRect) -> [CGRect] {
        let total = values.reduce(0, +)
        guard total > 0, rect.width > 0, rect.height > 0 else { return values.map { _ in .zero } }
        let scale = Double(rect.width * rect.height) / total
        let areas = values.map { $0 * scale }
        var out: [CGRect] = []
        var r = rect
        var i = 0
        while i < areas.count {
            let side = Double(min(r.width, r.height))
            guard side > 0 else { out += Array(repeating: .zero, count: areas.count - i); break }
            var row = [areas[i]]
            var j = i + 1
            while j < areas.count, worst(row + [areas[j]], side) <= worst(row, side) {
                row.append(areas[j]); j += 1
            }
            let sum = row.reduce(0, +)
            if r.width >= r.height {
                let w = CGFloat(sum / Double(r.height))
                var y = r.minY
                for a in row { let h = CGFloat(a) / w; out.append(CGRect(x: r.minX, y: y, width: w, height: h)); y += h }
                r = CGRect(x: r.minX + w, y: r.minY, width: r.width - w, height: r.height)
            } else {
                let h = CGFloat(sum / Double(r.width))
                var x = r.minX
                for a in row { let w = CGFloat(a) / h; out.append(CGRect(x: x, y: r.minY, width: w, height: h)); x += w }
                r = CGRect(x: r.minX, y: r.minY + h, width: r.width, height: r.height - h)
            }
            i = j
        }
        return out
    }

    private static func worst(_ row: [Double], _ side: Double) -> Double {
        let s = row.reduce(0, +)
        guard let mx = row.max(), let mn = row.min(), mn > 0, s > 0 else { return .infinity }
        return max(side * side * mx / (s * s), s * s / (side * side * mn))
    }
}
