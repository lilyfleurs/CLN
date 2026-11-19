import Foundation

enum CleanCategory: String, Codable, CaseIterable {
    case junk = "System Junk"
    case personal = "Personal Files"
    case apps = "Applications"
}

/// Running totals of what CLN has cleaned, kept in UserDefaults.
@MainActor
final class ActivityStore: ObservableObject {
    struct Stats: Codable {
        var cleaned: [String: Int64] = [:]
        var cleanups = 0
        var itemsRemoved = 0
        var tasksRun = 0
        var lastCleanup: Date?
        var since = Date()
        /// Module.rawValue -> when that screen last cleaned or ran something.
        var lastCleaned: [String: Date] = [:]
    }

    @Published private(set) var stats: Stats
    private let key = "cln.activity"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let s = try? JSONDecoder().decode(Stats.self, from: data) {
            stats = s
        } else {
            stats = Stats()
        }
    }

    var totalCleaned: Int64 { stats.cleaned.values.reduce(0, +) }
    func cleaned(_ c: CleanCategory) -> Int64 { stats.cleaned[c.rawValue] ?? 0 }

    /// Last clean for a module (its rawValue) or a section name such as "AI Clutter".
    func lastCleaned(_ key: String) -> Date? { stats.lastCleaned[key] }

    func record(_ category: CleanCategory, freed: Int64, count: Int, keys: [String]) {
        guard count > 0 else { return }
        stats.cleaned[category.rawValue, default: 0] += freed
        stats.itemsRemoved += count
        stats.lastCleanup = Date()
        for k in keys { stats.lastCleaned[k] = Date() }
        save()
    }

    /// Counts one cleanup run (which may span several categories).
    func recordRun() {
        stats.cleanups += 1
        save()
    }

    func recordTask(keys: [String]) {
        stats.tasksRun += 1
        for k in keys { stats.lastCleaned[k] = Date() }
        save()
    }

    func reload() {
        if let data = UserDefaults.standard.data(forKey: key),
           let s = try? JSONDecoder().decode(Stats.self, from: data) {
            stats = s
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct DiskInfo {
    var total: Int64
    var available: Int64
    var used: Int64 { total - available }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }

    static func current() -> DiskInfo {
        let url = URL(fileURLWithPath: "/")
        let v = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        return DiskInfo(total: Int64(v?.volumeTotalCapacity ?? 0),
                        available: v?.volumeAvailableCapacityForImportantUsage ?? 0)
    }
}
