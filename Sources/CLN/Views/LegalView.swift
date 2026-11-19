import SwiftUI

/// Terms, disclaimer and privacy statement. The legal text is kept in English on purpose:
/// one authoritative version is safer than unreviewed translations.
enum Legal {
    /// Bump when the terms change so people see the first-launch sheet again.
    static let termsVersion = "1"
    static let acceptedKey = "cln.termsAccepted"
    static let updated = "19 November 2026"

    static var sections: [(title: String, body: String)] {
        let contact = Links.contact.map { "Questions about these terms or your privacy can be sent as a message on Instagram: \($0)." }
            ?? "Questions about these terms or your privacy can be sent to the contact address published with CLN."
        return [
            ("Freeware",
             "CLN is freeware. You may use it free of charge on any number of Macs, for personal or business use, and share the original, unmodified download free of charge. Selling CLN, bundling it with other software, or distributing modified copies requires prior written permission. All rights not expressly granted remain with the author."),
            ("No warranty",
             "CLN is provided \"as is\" and \"as available\", without warranties of any kind, express or implied, including fitness for a particular purpose, accuracy of results, or uninterrupted and error-free operation. Results depend on your Mac, your macOS version and the software you have installed."),
            ("Your responsibility",
             "CLN only removes items you have selected, and moves them to the Trash so they can be restored. Emptying the Trash and some maintenance tasks are permanent. Please review every item before cleaning and keep a current backup of your Mac, for example with Time Machine. When Auto-Clean is turned on, CLN removes only the recommended System Junk, on the schedule you choose, and you can turn it off at any time."),
            ("Limitation of liability",
             "To the fullest extent permitted by applicable law, the author is not liable for any direct, indirect, incidental or consequential damage, including loss of data, system malfunction, or loss of profit, arising from the use of or inability to use CLN. Nothing in these terms limits liability that cannot be limited by law, in particular liability for intent or gross negligence, or for injury to life, body or health, or your statutory rights as a consumer."),
            ("Privacy",
             "CLN does not collect, store or transmit any personal data. There are no accounts, no analytics, no tracking, no advertising and no third-party SDKs. All scanning happens locally on your Mac; file names, paths and sizes never leave it. CLN only goes online when you ask it to: when you click a link, such as the tip button, which opens the page in your browser and is then covered by that website's own privacy policy; when you scan Apps or click Check for Updates, which asks Apple's App Store and the update feeds published by app developers for the latest version numbers; and once a day to ask GitHub whether a newer version of CLN itself is out. Those requests contain only the identifiers of your installed apps or CLN's own version, nothing about you or your files. Your settings and cleaning history are stored only on your Mac, in CLN's preferences, and are removed when you delete the app and its preferences."),
            ("Permissions",
             "Full Disk Access is optional. It is used only to read the size and contents of your Trash and of Mail's attachment folder. Some maintenance tasks ask for your administrator password; that prompt comes from macOS, and CLN never sees or stores your password. CLN asks Finder to empty the Trash and to remove apps that need your permission. Auto-Clean installs a small schedule in your user LaunchAgents folder, which is removed when you turn Auto-Clean off."),
            ("Trademarks",
             "Apple, Mac, macOS, Finder, Spotlight, Time Machine and Xcode are trademarks of Apple Inc. Other product names mentioned in CLN, such as Claude, ChatGPT, Codex, Cursor, Gemini and Ollama, belong to their respective owners. CLN is an independent app and is not affiliated with, sponsored or endorsed by any of them."),
            ("Changes and contact",
             "These terms may be updated with new versions of CLN; the version shown here applies to the version you are using. \(contact)"),
        ]
    }
}

/// Full About & Legal screen, opened from the sidebar.
struct LegalSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    CLNLogo(size: 40)
                    SwissLabel(text: L("Privacy · Terms"))
                    if Links.repo != nil { UpdateStatus() }
                }
                Spacer()
                Button(L("Close")) { dismiss() }.buttonStyle(GhostButtonStyle())
            }
            .padding(28)
            Hairline()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(L("CLN is free, works entirely on your Mac and collects no data."))
                        .font(Theme.display(18, .regular))
                    ForEach(Array(Legal.sections.enumerated()), id: \.offset) { i, s in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Text(String(format: "%02d", i + 1)).font(Theme.mono()).foregroundStyle(Theme.ink.opacity(0.4))
                                Text(s.title.uppercased()).font(Theme.caps(12, .bold)).tracking(2)
                            }
                            Text(s.body).font(.system(size: 13)).foregroundStyle(Theme.ink.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                    Text(L("The legal text is provided in English.") + " · v\(AppInfo.version) · " + Legal.updated)
                        .font(Theme.mono(10)).foregroundStyle(Theme.ink.opacity(0.45))
                }
                .padding(28)
            }
        }
        .frame(width: 640, height: 640)
        .background(Backdrop())
        .foregroundStyle(Theme.ink)
    }
}

/// Shown once on first launch (and again if the terms change).
struct WelcomeTerms: View {
    let onAgree: () -> Void
    @State private var showFull = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            CLNLogo(size: 46)
            VStack(alignment: .leading, spacing: 6) {
                SwissLabel(text: L("Before you start"))
                Text(L("Welcome to CLN").uppercased()).font(Theme.caps(26, .bold)).tracking(0.8)
            }
            VStack(alignment: .leading, spacing: 14) {
                point("gift", L("CLN is freeware: free to use, with no ads or subscriptions."))
                point("lock.shield", L("Your data stays on your Mac. CLN collects and sends nothing."))
                point("trash", L("Cleaned items go to the Trash first. Review them before deleting."))
                point("doc.text", L("By using this app, you agree to the Terms & Conditions."))
            }
            HStack {
                Button(L("Read full terms")) { showFull = true }.buttonStyle(GhostButtonStyle())
                Spacer()
                Button(L("Agree & Continue"), action: onAgree).buttonStyle(PillButtonStyle(large: true))
            }
        }
        .padding(34)
        .frame(width: 560)
        .background(Backdrop())
        .foregroundStyle(Theme.ink)
        .sheet(isPresented: $showFull) { LegalSheet() }
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            IconTile(symbol: symbol, size: 34)
            Text(text).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true).padding(.top, 7)
        }
    }
}
