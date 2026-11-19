import CryptoKit
import Foundation

enum ClutterScanner {
    struct Entry {
        let url: URL
        let size: Int64
        let modified: Date?
    }

    static func scan(root: URL, cancel: CancelFlag, progress: (String) -> Void) -> [CleanGroup] {
        let files = collect(root: root, cancel: cancel, progress: progress)
        let yearAgo = Date().addingTimeInterval(-365 * 86_400)

        let large = files.filter { $0.size >= 100_000_000 }.sorted { $0.size > $1.size }
        let largeSet = Set(large.map(\.url))
        let old = files.filter { !largeSet.contains($0.url) && $0.size >= 10_000_000 && ($0.modified ?? .distantFuture) < yearAgo }
            .sorted { $0.size > $1.size }

        progress("Comparing files for duplicates…")
        let dups = cancel.isCancelled ? [] : duplicates(files, cancel: cancel)

        var groups = [
            CleanGroup(title: Sec.large, symbol: "externaldrive", subtitle: Sec.info(Sec.large).blurb, section: Sec.large,
                       items: large.map(item)),
            CleanGroup(title: Sec.old, symbol: "clock.arrow.circlepath", subtitle: Sec.info(Sec.old).blurb, section: Sec.old,
                       items: old.map(item)),
            CleanGroup(title: Sec.dups, symbol: "doc.on.doc", subtitle: Sec.info(Sec.dups).blurb, section: Sec.dups,
                       items: dups),
        ]
        progress("Looking at Downloads…")
        groups.append(CleanGroup(title: Sec.downloads, symbol: "arrow.down.circle", subtitle: Sec.info(Sec.downloads).blurb,
                                 section: Sec.downloads, items: downloads(olderThanDays: nil)))
        return groups.filter { !$0.items.isEmpty }
    }

    private static func item(_ e: Entry) -> CleanItem {
        CleanItem(url: e.url, name: e.url.lastPathComponent,
                  detail: FS.tilde(e.url.deletingLastPathComponent().path), size: e.size, date: e.modified)
    }

    /// Top-level items in ~/Downloads, oldest first. `olderThanDays` limits to items added before then.
    static func downloads(olderThanDays days: Int?) -> [CleanItem] {
        let dir = FS.home.appendingPathComponent("Downloads")
        let cutoff = days.map { Date().addingTimeInterval(-Double($0) * 86_400) }
        return FS.children(dir).compactMap { u -> CleanItem? in
            guard u.lastPathComponent != ".DS_Store", u.lastPathComponent != ".localized" else { return nil }
            let v = try? u.resourceValues(forKeys: [.addedToDirectoryDateKey, .contentModificationDateKey])
            let added = v?.addedToDirectoryDate ?? v?.contentModificationDate
            if let cutoff, let added, added > cutoff { return nil }
            let size = FS.size(of: u)
            guard size > 0 else { return nil }
            return CleanItem(url: u, name: u.lastPathComponent, detail: "Added \(FS.relative(added))", size: size, date: added)
        }
        .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    private static func collect(root: URL, cancel: CancelFlag, progress: (String) -> Void) -> [Entry] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isPackageKey, .totalFileAllocatedSizeKey,
                                      .fileAllocatedSizeKey, .contentModificationDateKey]
        let skip = Set([FS.lib("").path, FS.home.appendingPathComponent(".Trash").path,
                        FS.lib("").standardizedFileURL.path].filter { $0 != root.path })
        guard let e = FS.fm.enumerator(at: root, includingPropertiesForKeys: keys,
                                       options: [.skipsHiddenFiles, .skipsPackageDescendants],
                                       errorHandler: { _, _ in true }) else { return [] }
        var out: [Entry] = []
        var n = 0
        while let u = e.nextObject() as? URL {
            if cancel.isCancelled { break }
            if skip.contains(u.path) || skip.contains(u.path + "/") { e.skipDescendants(); continue }
            guard let v = try? u.resourceValues(forKeys: Set(keys)) else { continue }
            if v.isPackage == true { continue }
            guard v.isRegularFile == true else { continue }
            n += 1
            if n % 400 == 0 { progress("\(SpaceScanner.topFolder(u, under: root)) · \(n.formatted()) files") }
            // Allocated size is 0 for iCloud files not on this Mac, so those are never read or downloaded.
            let size = Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
            ScanTicker.shared.saw(u, size: size)
            if size >= 1_000_000 { out.append(Entry(url: u, size: size, modified: v.contentModificationDate)) }
        }
        return out
    }

    /// Extra copies of identical files; the oldest copy in each set is treated as the original and not listed.
    private static func duplicates(_ files: [Entry], cancel: CancelFlag) -> [CleanItem] {
        var out: [CleanItem] = []
        for sameSize in Dictionary(grouping: files, by: \.size).values where sameSize.count > 1 {
            if cancel.isCancelled { break }
            for (k, sameHead) in Dictionary(grouping: sameSize, by: { hash($0.url, limit: 65_536) }) where k != nil && sameHead.count > 1 {
                for (k2, same) in Dictionary(grouping: sameHead, by: { hash($0.url, limit: nil) }) where k2 != nil && same.count > 1 {
                    let sorted = same.sorted { ($0.modified ?? .distantPast) < ($1.modified ?? .distantPast) }
                    let original = sorted[0]
                    for dup in sorted.dropFirst() {
                        out.append(CleanItem(url: dup.url, name: dup.url.lastPathComponent,
                                             detail: "Copy of \(FS.tilde(original.url.path))", size: dup.size, date: dup.modified))
                    }
                }
            }
        }
        return out.sorted { $0.size > $1.size }
    }

    private static func hash(_ url: URL, limit: Int?) -> String? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        var hasher = SHA256()
        var remaining = limit ?? Int.max
        while remaining > 0 {
            guard let chunk = try? h.read(upToCount: min(1 << 20, remaining)), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
            remaining -= chunk.count
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
