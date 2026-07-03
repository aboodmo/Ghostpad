//
//  Shortcut.swift
//  Ghostpad
//
//  The hotkey model: a Carbon virtual key code, a Carbon modifier mask, and a
//  display label. Owns every Carbon-facing detail — display glyphs, NSEvent
//  conversion, UserDefaults persistence, and the curated system-conflict
//  list — so views never import Carbon themselves.
//

import AppKit
import Carbon.HIToolbox

struct Shortcut: Equatable {
    var keyCode: Int
    var modifiers: Int   // Carbon mask: cmdKey | optionKey | controlKey | shiftKey
    var label: String    // display label for the key, e.g. "G", "Space", "←"

    init(keyCode: Int, modifiers: Int, label: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }

    static let defaultShowHide = Shortcut(keyCode: kVK_ANSI_G, modifiers: cmdKey | optionKey, label: "G")
    static let defaultClickThrough = Shortcut(keyCode: kVK_ANSI_T, modifiers: cmdKey | optionKey, label: "T")

    /// A global hotkey needs at least one of ⌘ / ⌥ / ⌃.
    var hasRequiredModifier: Bool {
        modifiers & (cmdKey | optionKey | controlKey) != 0
    }

    /// ⌃⌥⇧⌘ + key, in the canonical macOS order.
    var display: String {
        var s = ""
        if modifiers & controlKey != 0 { s += "⌃" }
        if modifiers & optionKey  != 0 { s += "⌥" }
        if modifiers & shiftKey   != 0 { s += "⇧" }
        if modifiers & cmdKey     != 0 { s += "⌘" }
        return s + label
    }

    func matches(_ other: Shortcut) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }

    // MARK: - NSEvent bridge (used by the Settings recorder)

    /// The combo a key-down event represents.
    init(event: NSEvent) {
        keyCode = Int(event.keyCode)
        modifiers = Shortcut.carbonModifiers(event.modifierFlags)
        label = Shortcut.keyLabel(event)
    }

    /// Escape is reserved: it cancels the recorder rather than being recordable.
    static func isEscape(_ event: NSEvent) -> Bool {
        Int(event.keyCode) == kVK_Escape
    }

    /// Menu-item key-equivalent form — single letter/digit combos only
    /// (anything fancier stays off the menu).
    var menuKeyEquivalent: (key: String, modifiers: NSEvent.ModifierFlags)? {
        guard label.count == 1, let c = label.lowercased().first, c.isLetter || c.isNumber else {
            return nil
        }
        var mask: NSEvent.ModifierFlags = []
        if modifiers & cmdKey     != 0 { mask.insert(.command) }
        if modifiers & optionKey  != 0 { mask.insert(.option) }
        if modifiers & controlKey != 0 { mask.insert(.control) }
        if modifiers & shiftKey   != 0 { mask.insert(.shift) }
        return (String(c), mask)
    }

    private static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if flags.contains(.command) { m |= cmdKey }
        if flags.contains(.option)  { m |= optionKey }
        if flags.contains(.control) { m |= controlKey }
        if flags.contains(.shift)   { m |= shiftKey }
        return m
    }

    private static func keyLabel(_ event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space:      return "Space"
        case kVK_Return:     return "↩"
        case kVK_Tab:        return "⇥"
        case kVK_Delete:     return "⌫"
        case kVK_LeftArrow:  return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow:    return "↑"
        case kVK_DownArrow:  return "↓"
        default:
            let s = event.charactersIgnoringModifiers ?? ""
            return s.isEmpty ? "Key \(event.keyCode)" : s.uppercased()
        }
    }

    // MARK: - Persistence (piecewise under a prefix)

    static func load(prefix: String, from defaults: UserDefaults = .standard) -> Shortcut {
        Shortcut(
            keyCode: defaults.integer(forKey: "\(prefix).keyCode"),
            modifiers: defaults.integer(forKey: "\(prefix).modifiers"),
            label: defaults.string(forKey: "\(prefix).label") ?? ""
        )
    }

    func save(prefix: String, to defaults: UserDefaults = .standard) {
        defaults.set(keyCode, forKey: "\(prefix).keyCode")
        defaults.set(modifiers, forKey: "\(prefix).modifiers")
        defaults.set(label, forKey: "\(prefix).label")
    }

    func registrationDefaults(prefix: String) -> [String: Any] {
        [
            "\(prefix).keyCode": keyCode,
            "\(prefix).modifiers": modifiers,
            "\(prefix).label": label,
        ]
    }

    // MARK: - Conflict awareness

    /// The in-panel editor shortcuts — listed read-only in Settings and used
    /// for conflict warnings when recording a global hotkey.
    static let builtIns: [(name: String, shortcut: Shortcut)] = [
        ("Toggle Sidebar", Shortcut(keyCode: kVK_ANSI_B, modifiers: cmdKey, label: "B")),
        ("New Note",       Shortcut(keyCode: kVK_ANSI_N, modifiers: cmdKey, label: "N")),
        ("Delete Note",    Shortcut(keyCode: kVK_Delete, modifiers: cmdKey, label: "⌫")),
        ("Opacity Up",     Shortcut(keyCode: kVK_UpArrow, modifiers: cmdKey, label: "↑")),
        ("Opacity Down",   Shortcut(keyCode: kVK_DownArrow, modifiers: cmdKey, label: "↓")),
    ]

    /// Best-effort only: macOS exposes no API to enumerate every global
    /// shortcut, so this matches a curated set of common system defaults —
    /// enough to warn, never a guarantee.
    var conflictsWithSystemShortcut: Bool {
        Shortcut.systemReserved.contains { matches($0) }
    }

    private static func sys(_ k: Int, _ m: Int) -> Shortcut {
        Shortcut(keyCode: k, modifiers: m, label: "")
    }

    static let systemReserved: [Shortcut] = [
        sys(kVK_Space, cmdKey),                  // Spotlight
        sys(kVK_Space, controlKey),              // Previous input source
        sys(kVK_Space, controlKey | optionKey),  // Input source
        sys(kVK_ANSI_3, cmdKey | shiftKey),      // Screenshot to file
        sys(kVK_ANSI_4, cmdKey | shiftKey),      // Screenshot selection
        sys(kVK_ANSI_5, cmdKey | shiftKey),      // Screenshot toolbar
        sys(kVK_UpArrow, controlKey),            // Mission Control
        sys(kVK_DownArrow, controlKey),          // Application windows
        sys(kVK_LeftArrow, controlKey),          // Move one space left
        sys(kVK_RightArrow, controlKey),         // Move one space right
        sys(kVK_Escape, cmdKey | optionKey),     // Force Quit
        sys(kVK_ANSI_Q, cmdKey | controlKey),    // Lock screen
        sys(kVK_Tab, cmdKey),                    // App switcher
    ]
}
