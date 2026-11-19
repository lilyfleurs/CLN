import AppKit
import SwiftUI

/// "Check for Updates" button for the Apps screen, with the results in a sheet.
struct UpdatesButton: View {
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            Label(L("Check for Updates"), systemImage: "arrow.down.app")
        }
        .buttonStyle(GhostButtonStyle())
        .sheet(isPresented: $show) { UpdatesSheet() }
    }
}

struct UpdatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var updates: [AppUpdate]?
    @State private var checked = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    SwissLabel(text: "\(Module.applications.number) — \(Module.applications.title)")
                    Text(L("Check for Updates").uppercased()).font(Theme.caps(24, .bold)).tracking(0.8)
                }
                Spacer()
                Button(L("Close")) { dismiss() }.buttonStyle(GhostButtonStyle())
            }

            if let updates {
                Text(updates.isEmpty ? L("All apps are up to date.") : L("%@ updates available", "\(updates.count)"))
                    .font(Theme.display(18, .regular))
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(updates) { row($0) }
                    }
                }
                Text(L("Checked %@ apps from the App Store and developer update feeds. Apps that update another way aren't listed.", "\(checked)"))
                    .font(.caption).foregroundStyle(Theme.ink.opacity(0.55))
            } else {
                HStack(spacing: 12) {
                    ProgressView().controlSize(.small)
                    Text(L("Checking for updates…")).font(Theme.display(16, .regular))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Text(L("Only app identifiers are sent; nothing about you or your files."))
                .font(Theme.mono(9.5)).foregroundStyle(Theme.ink.opacity(0.45))
        }
        .padding(28)
        .frame(width: 600, height: 520)
        .background(Backdrop())
        .foregroundStyle(Theme.ink)
        .task {
            let r = await UpdateChecker.check()
            updates = r.updates
            checked = r.checked
        }
    }

    private func row(_ u: AppUpdate) -> some View {
        HStack(spacing: 12) {
            FileIcon(path: u.appURL.path, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(u.name).font(Theme.display(15, .regular))
                Text("\(u.current) → \(u.latest) · \(u.fromAppStore ? "App Store" : L("Developer"))")
                    .font(Theme.mono(10.5)).foregroundStyle(Theme.ink.opacity(0.55))
            }
            Spacer()
            Button(u.fromAppStore ? L("Open App Store") : L("Open App")) {
                // CLN never installs anything itself: the App Store or the app's own updater does.
                NSWorkspace.shared.open(u.link ?? u.appURL)
            }
            .buttonStyle(PillButtonStyle())
        }
        .glassCard(radius: 14, padding: 12)
    }
}
