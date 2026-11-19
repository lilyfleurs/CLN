import Foundation

enum AutoFrequency: String, CaseIterable, Identifiable {
    case off, daily, weekly, biweekly, monthly

    var id: String { rawValue }
    var days: Int { [0, 1, 7, 14, 30][AutoFrequency.allCases.firstIndex(of: self)!] }
    var label: String { L(englishLabel) }

    var englishLabel: String {
        switch self {
        case .off: "Off"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Monthly"
        }
    }
}

/// Timed auto-clean. A user launch agent starts CLN with `--autoclean` every morning;
/// CLN then cleans only if the chosen interval has passed. It only removes the
/// recommended System Junk (the items preselected on the System Junk card).
enum AutoClean {
    static let agentLabel = "com.lilyfleurs.cln.autoclean"
    static var agentURL: URL { FS.lib("LaunchAgents/\(agentLabel).plist") }
    private static let freqKey = "cln.autoclean.frequency"
    private static let lastKey = "cln.autoclean.last"
    private static let freedKey = "cln.autoclean.lastFreed"
    static let hour = 10, minute = 30

    static var frequency: AutoFrequency {
        AutoFrequency(rawValue: UserDefaults.standard.string(forKey: freqKey) ?? "") ?? .off
    }

    static var lastRun: Date? { UserDefaults.standard.object(forKey: lastKey) as? Date }
    static var lastFreed: Int64 { Int64(UserDefaults.standard.integer(forKey: freedKey)) }

    /// Saves the choice and installs or removes the launch agent. Returns an error message on failure.
    @discardableResult
    static func set(_ f: AutoFrequency) -> String? {
        UserDefaults.standard.set(f.rawValue, forKey: freqKey)
        Shell.run("/bin/launchctl", ["bootout", "gui/\(getuid())", agentURL.path])
        try? FS.fm.removeItem(at: agentURL)
        guard f != .off else { return nil }

        guard Bundle.main.bundleURL.pathExtension == "app", let exe = Bundle.main.executablePath else {
            return "Auto-clean only works when CLN runs as an app (CLN.app), not from the command line."
        }
        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": [exe, "--autoclean"],
            "StartCalendarInterval": ["Hour": hour, "Minute": minute],
            "ProcessType": "Background",
            "LowPriorityIO": true,
        ]
        do {
            try FS.fm.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: agentURL)
        } catch {
            return "Couldn't save the schedule: \(error.localizedDescription)"
        }
        let r = Shell.run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", agentURL.path])
        return r.status == 0 ? nil : "macOS didn't accept the schedule: \(r.output)"
    }

    /// The schedule remembers where CLN was when it was set. If the app has moved since (say from
    /// Downloads to Applications), or the schedule file has gone missing, write it again.
    static func followAppIfMoved() {
        guard frequency != .off, let exe = Bundle.main.executablePath else { return }
        guard let data = try? Data(contentsOf: agentURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let args = plist["ProgramArguments"] as? [String], args.first == exe else {
            set(frequency)
            return
        }
    }

    static func isDue(_ now: Date = Date()) -> Bool {
        guard frequency != .off else { return false }
        guard let last = lastRun else { return true }
        // A few hours of slack so a run that started late yesterday doesn't push today's run back.
        return now.timeIntervalSince(last) >= Double(frequency.days) * 86_400 - 3 * 3600
    }

    static var nextRun: Date? {
        guard frequency != .off else { return nil }
        let due = lastRun.map { $0.addingTimeInterval(Double(frequency.days) * 86_400 - 3 * 3600) } ?? Date()
        let start = max(due, Date())
        let cal = Calendar.current
        var c = cal.dateComponents([.year, .month, .day], from: start)
        c.hour = hour
        c.minute = minute
        var d = cal.date(from: c) ?? start
        if d < start { d = cal.date(byAdding: .day, value: 1, to: d) ?? d }
        return d
    }

    /// Entry point for `CLN --autoclean`. Runs without any window and returns when done.
    @MainActor
    static func runHeadless() {
        guard isDue() else { return }
        let items = JunkScanner.scan { _ in }.filter { $0.section == Sec.junk }.selectedItems
        let (result, _) = FS.trash(items)
        UserDefaults.standard.set(Date(), forKey: lastKey)
        UserDefaults.standard.set(Int(result.freed), forKey: freedKey)
        let activity = ActivityStore()
        activity.record(.junk, freed: result.freed, count: result.count,
                        keys: [Sec.junk, Module.cleanup.rawValue, Module.overview.rawValue, "autoclean"])
        if result.count > 0 { activity.recordRun() }
        UserDefaults.standard.synchronize()
    }
}
