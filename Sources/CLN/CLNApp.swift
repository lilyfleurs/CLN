import AppKit
import SwiftUI

@main
struct CLNApp: App {
    @StateObject private var activity = ActivityStore()

    init() {
        // Launched by the auto-clean agent: clean if due, then quit without showing a window.
        if CommandLine.arguments.contains("--autoclean") {
            MainActor.assumeIsolated { AutoClean.runHeadless() }
            exit(0)
        }
        // Prints each app's leftovers as the uninstaller sees them. Removes nothing.
        if CommandLine.arguments.contains("--apps-report") {
            for g in AppScanner.scan(progress: { _ in }) where g.section == "Apps" {
                print("\(g.title): \(g.items.count) items, \(FS.format(g.totalSize))")
                for i in g.items.dropFirst() { print("    \(i.detail)") }
            }
            exit(0)
        }
        // Prints what a scan would find, removes nothing. Handy for checking the scanners.
        if CommandLine.arguments.contains("--scan-report") {
            var groups = JunkScanner.scan { _ in }
            groups.append(CleanGroup(title: "Orphaned", symbol: "", section: Sec.leftovers, items: AppScanner.orphanedLeftovers()))
            groups.append(CleanGroup(title: "Broken agents", symbol: "", section: Sec.startup, items: LaunchScanner.brokenItems()))
            for g in groups {
                print("[\(g.section)] \(g.title): \(g.items.count) items, \(FS.format(g.totalSize)), selected \(FS.format(g.selectedSize))")
                for i in g.items.prefix(4) { print("    \(i.selected ? "x" : " ") \(i.name) — \(FS.format(i.size)) — \(i.detail)") }
            }
            exit(0)
        }
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
            MainActor.assumeIsolated { Snapshots.run(to: CommandLine.arguments[i + 1]) }
            exit(0)
        }
        NSApplication.shared.setActivationPolicy(.regular)
        AutoClean.followAppIfMoved()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(activity)
                .frame(minWidth: 1120, idealWidth: 1280, minHeight: 720, idealHeight: 800)
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
        .windowStyle(.hiddenTitleBar)
        #if !LEGACY
        .defaultSize(width: 1280, height: 800)
        #endif
    }
}
