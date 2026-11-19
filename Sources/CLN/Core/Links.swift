import Foundation

/// External links shown in the app. Fill these in before sharing CLN.
enum Links {
    /// Where the coffee button goes.
    static let tip: URL? = URL(string: "https://ko-fi.com/lilyfleurs")

    /// GitHub repository CLN updates itself from ("username/CLN"). nil turns update checks off.
    static let repo: String? = "lilyfleurs/CLN"

    /// Where people can find CLN and your other apps.
    static let website: URL? = nil

    /// Shown in the terms as the way to reach you. nil hides it.
    static let contact: String? = "instagram.com/lilyfleurss"
}

enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
