import Foundation

/// Languages CLN can be shown in. English strings are the keys; other languages live in
/// `Translations.swift`. Anything missing from a table falls back to English.
enum Lang: String, CaseIterable, Identifiable {
    case en, it, de, fr, es

    var id: String { rawValue }

    /// Each language named in itself, as language pickers usually do.
    var nativeName: String {
        switch self {
        case .en: "English"
        case .it: "Italiano"
        case .de: "Deutsch"
        case .fr: "Français"
        case .es: "Español"
        }
    }

    static let storageKey = "cln.language"

    /// The chosen language, or the Mac's own language when it's one CLN speaks.
    static var current: Lang {
        if let saved = UserDefaults.standard.string(forKey: storageKey), let l = Lang(rawValue: saved) { return l }
        let preferred = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
        return Lang(rawValue: preferred) ?? .en
    }

    var locale: Locale { Locale(identifier: rawValue) }
}

/// Translates an English UI string into the current language.
func L(_ key: String) -> String {
    let lang = Lang.current
    guard lang != .en else { return key }
    return Translations.table[lang]?[key] ?? key
}

/// Translates a format string (with %@ placeholders) and fills it in.
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}
