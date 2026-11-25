import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var activity: ActivityStore
    @State private var module: Module = .activity
    @StateObject private var overview = SectionModel.overview()
    @StateObject private var cleanup = SectionModel.cleanup()
    @StateObject private var clutter = SectionModel.clutter()
    @StateObject private var apps = SectionModel.apps()
    @StateObject private var performance = PerformanceModel()
    @StateObject private var space = SpaceLensModel()
    /// Changing language rebuilds the views so every string is looked up again.
    @AppStorage(Lang.storageKey) private var language = ""
    @AppStorage(Legal.acceptedKey) private var acceptedTerms = ""

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(selection: $module)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 28)
        }
        .id(language)
        .background(Backdrop())
        .foregroundStyle(Theme.ink)
        .tint(Theme.ink)
        .preferredColorScheme(.light)
        .sheet(isPresented: Binding(get: { acceptedTerms != Legal.termsVersion }, set: { _ in })) {
            WelcomeTerms { acceptedTerms = Legal.termsVersion }
                .interactiveDismissDisabled()
        }
    }

    @ViewBuilder private var detail: some View {
        switch module {
        case .overview:
            SectionModuleView(model: overview, showAutoClean: true) { AutoCleanCard().frame(maxWidth: 470) }
        case .cleanup:
            SectionModuleView(model: cleanup)
        case .performance:
            PerformanceView(model: performance)
        case .applications:
            SectionModuleView(model: apps) { UpdatesButton() }
        case .clutter:
            SectionModuleView(model: clutter) { FolderPicker(root: $clutter.root) }
        case .spaceLens:
            SpaceLensView(model: space)
        case .activity:
            ActivityView(go: { module = $0 }, onScan: {
                module = .overview
                overview.scan()
            })
        }
    }
}

struct Sidebar: View {
    @Binding var selection: Module
    @EnvironmentObject private var activity: ActivityStore

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            CLNLogo(size: 50)
            .padding(.horizontal, 14)
            .padding(.bottom, 26)

            ForEach(Module.allCases) { row($0) }
            Spacer()
            SidebarFooter()
                .padding(.horizontal, 10)
        }
        .padding(.top, 50)
        .padding(.bottom, 18)
        .padding(.horizontal, 10)
        .frame(width: 222)
        .background(.white.opacity(0.14))
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.ink.opacity(0.12)).frame(width: 0.5) }
    }

    private func row(_ m: Module) -> some View {
        let on = m == selection
        return Button { selection = m } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(m.number).font(Theme.mono()).foregroundStyle(Theme.ink.opacity(on ? 0.6 : 0.35))
                VStack(alignment: .leading, spacing: 3) {
                    Text(m.title.uppercased()).font(Theme.caps(12, on ? .semibold : .medium)).tracking(1)
                        .foregroundStyle(Theme.ink)
                    if m != .activity {
                        Text((activity.lastCleaned(m.rawValue).map { FS.relative($0) } ?? L("never cleaned")).uppercased())
                            .font(Theme.mono(9)).tracking(0.3).foregroundStyle(Theme.ink.opacity(on ? 0.55 : 0.4))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                if on { InkGlass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous), knob: true) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Bottom of the sidebar: language picker, tip button, a short thank-you line, the terms and
/// the light / see-through switch.
struct SidebarFooter: View {
    @AppStorage(Lang.storageKey) private var language = ""
    @State private var showLegal = false
    @State private var showLanguages = false
    @ObservedObject private var updater = SelfUpdate.shared
    @State private var confirmUpdate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let r = updater.available {
                Button(updater.state == .downloading ? L("Updating…") : L("Update to %@", r.version)) { confirmUpdate = true }
                    .buttonStyle(PillButtonStyle(scan: true))
                    .disabled(updater.state == .downloading)
                if case .failed(let message) = updater.state {
                    Text(message).font(.caption2).foregroundStyle(Theme.bad).fixedSize(horizontal: false, vertical: true)
                }
            }
            tipRow
            HStack {
                Button { showLegal = true } label: {
                    Text(L("Privacy · Terms").uppercased())
                        .font(Theme.mono(8.5)).tracking(1.2)
                        .foregroundStyle(Theme.ink.opacity(0.45))
                }
                .buttonStyle(.plain)
                Spacer()
                AppearanceSwitch()
            }
        }
        .sheet(isPresented: $showLegal) { LegalSheet() }
        .onAppear { updater.checkIfDue() }
        .alert(L("Update CLN to %@?", updater.available?.version ?? ""), isPresented: $confirmUpdate) {
            Button(L("Update & Restart")) { updater.install() }
            Button(L("What's New")) { if let r = updater.available { NSWorkspace.shared.open(r.page) } }
            Button(L("Later"), role: .cancel) {}
        } message: {
            Text(L("CLN downloads the new version from GitHub, replaces this one and opens again. Your settings and history stay. The old version goes to the Trash."))
        }
    }

    private var tipRow: some View {
        HStack(spacing: 10) {
            Button { withAnimation(.quick(0.2)) { showLanguages.toggle() } } label: {
                IconTile(symbol: "globe", size: 32)
            }
            .buttonStyle(.plain)
            .help(L("Language"))
            // Glass panel above the globe, like the other boxes (a system menu can't be see-through)
            .overlay(alignment: .bottomLeading) {
                if showLanguages { languagePanel.offset(y: -42).transition(.opacity.combined(with: .offset(y: 6))) }
            }
            .zIndex(1)

            Button {
                if let url = Links.tip { NSWorkspace.shared.open(url) }
            } label: {
                IconTile(symbol: "cup.and.saucer", size: 32)
            }
            .buttonStyle(.plain)
            .help(L("Leave a tip"))

            VStack(alignment: .leading, spacing: 2) {
                Text(L("Enjoying CLN?")).font(Theme.caps(10, .semibold)).tracking(0.6)
                Text(L("A tip keeps apps like this coming."))
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.ink.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .onTapGesture { if let url = Links.tip { NSWorkspace.shared.open(url) } }
        }
    }

    private var languagePanel: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Lang.allCases) { lang in
                let on = lang == Lang.current
                Button {
                    language = lang.rawValue
                    showLanguages = false
                } label: {
                    HStack {
                        Text(lang.nativeName.uppercased()).font(Theme.caps(11, on ? .semibold : .medium)).tracking(1)
                        Spacer()
                        if on { Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold)) }
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background { if on { InkGlass(shape: Capsule(), knob: true) } }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .frame(width: 170)
        .background(MilkGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)))
        .fixedSize()
    }
}

/// Sun: the misty blue look. Moon: see-through, the desktop shows behind the glass.
struct AppearanceSwitch: View {
    @AppStorage(Appearance.key) private var appearance = Appearance.light.rawValue

    var body: some View {
        HStack(spacing: 0) {
            option(.light, "sun.max", L("Light"))
            option(.glass, "moon", L("See-through"))
        }
        .padding(2)
        .background(LensGlass(shape: Capsule()))
    }

    private func option(_ a: Appearance, _ symbol: String, _ help: String) -> some View {
        let on = appearance == a.rawValue
        return Button { withAnimation(.quick(0.25)) { appearance = a.rawValue } } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: on ? .semibold : .regular))
                .foregroundStyle(Theme.ink.opacity(on ? 1 : 0.5))
                .frame(width: 24, height: 18)
                .background { if on { InkGlass(shape: Capsule(), knob: true) } }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// "Check for Updates" with the result, for the terms sheet.
struct UpdateStatus: View {
    @ObservedObject private var updater = SelfUpdate.shared

    var body: some View {
        HStack(spacing: 10) {
            Button(L("Check for Updates")) { updater.check() }
                .buttonStyle(GhostButtonStyle())
                .disabled(updater.state == .checking || updater.state == .downloading)
            Group {
                switch updater.state {
                case .checking: Text(L("Checking…"))
                case .upToDate: Text(L("CLN is up to date."))
                case .failed(let m): Text(m)
                default:
                    if let r = updater.available { Text(L("Version %@ is available.", r.version)) }
                }
            }
            .font(Theme.mono(10)).foregroundStyle(Theme.ink.opacity(0.6))
        }
    }
}
