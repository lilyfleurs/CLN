import AppKit
import SwiftUI

// Fallbacks so the same code runs on macOS 12 Monterey. On macOS 13 and 14 each one uses the
// newer SwiftUI feature, so nothing changes there; on 12 it uses the closest older equivalent.

extension View {
    /// Letter spacing on any view (13+); plain spacing on 12.
    @ViewBuilder func compatTracking(_ value: CGFloat) -> some View {
        if #available(macOS 13, *) { tracking(value) } else { self }
    }

    /// Counting animation for changing numbers (13+).
    @ViewBuilder func numericTransition() -> some View {
        if #available(macOS 13, *) { contentTransition(.numericText()) } else { self }
    }

    /// Swaps text without a crossfade (13+).
    @ViewBuilder func identityTransition() -> some View {
        if #available(macOS 13, *) { contentTransition(.identity) } else { self }
    }

    /// Hides the blue focus ring around a focusable area (14+; 12 and 13 show none here anyway
    /// because the area draws its own background).
    @ViewBuilder func noFocusRing() -> some View {
        if #available(macOS 14, *) { focusEffectDisabled() } else { self }
    }

    /// Runs `action` with the new value whenever `value` changes.
    @ViewBuilder func whenChanged<V: Equatable>(_ value: V, _ action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14, *) {
            onChange(of: value) { _, new in action(new) }
        } else {
            onChange(of: value, perform: action)
        }
    }

    /// A menu drawn as a plain button (13+), borderless on 12.
    @ViewBuilder func buttonMenuStyle() -> some View {
        if #available(macOS 13, *) { menuStyle(.button) } else { menuStyle(.borderlessButton) }
    }

    /// Space and arrow keys, like Finder. Each handler returns true when it used the key.
    /// On 14 this is SwiftUI's key handling on the focused view; on 12 and 13 it listens to
    /// key presses in the app while the view is on screen, and leaves typing in text fields alone.
    @ViewBuilder func onListKeys(space: @escaping () -> Bool,
                                 down: @escaping () -> Bool = { false },
                                 up: @escaping () -> Bool = { false }) -> some View {
        if #available(macOS 14, *) {
            onKeyPress(.space) { space() ? .handled : .ignored }
                .onKeyPress(.downArrow) { down() ? .handled : .ignored }
                .onKeyPress(.upArrow) { up() ? .handled : .ignored }
        } else {
            modifier(KeyMonitor(space: space, down: down, up: up))
        }
    }
}

/// Older macOS: a local key monitor installed while the view is shown.
private struct KeyMonitor: ViewModifier {
    let space: () -> Bool, down: () -> Bool, up: () -> Bool
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    // typing in a search or text field keeps its keys
                    if NSApp.keyWindow?.firstResponder is NSText { return event }
                    guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
                    let used: Bool
                    switch event.keyCode {
                    case 49: used = space()     // space
                    case 125: used = down()     // down arrow
                    case 126: used = up()       // up arrow
                    default: used = false
                    }
                    return used ? nil : event
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }
}

extension Animation {
    /// SwiftUI's quick "snappy" spring (14+); a matching short spring on older systems.
    static func quick(_ duration: Double) -> Animation {
        if #available(macOS 14, *) { return .snappy(duration: duration) }
        return .spring(response: duration, dampingFraction: 0.85)
    }
}

