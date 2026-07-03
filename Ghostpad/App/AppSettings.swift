//
//  AppSettings.swift
//  Ghostpad
//
//  One source of truth for every persisted setting: its key, its type, and
//  its default. @AppStorage sites, the AppDelegate's appliers, and the
//  UserDefaults registration all read from here, so they can never drift.
//

import Foundation

/// A typed UserDefaults entry: the key string plus its default value.
struct Pref<Value> {
    let key: String
    let defaultValue: Value

    init(_ key: String, _ defaultValue: Value) {
        self.key = key
        self.defaultValue = defaultValue
    }
}

enum AppSettings {
    static let panelOpacity    = Pref("panelOpacity", 0.6)
    static let editorFontSize  = Pref("editorFontSize", 15.0)
    static let theme           = Pref("theme", Theme.vapor.rawValue)
    static let alwaysOnTop     = Pref("alwaysOnTop", true)
    static let hideFromCapture = Pref("hideFromCapture", true)
    static let clickThrough    = Pref("clickThrough", false)

    /// Hotkeys are stored piecewise under a prefix (`<prefix>.keyCode`,
    /// `.modifiers`, `.label` — see `Shortcut.load/save`), plus a `.failed`
    /// flag the AppDelegate sets when the OS refuses the registration.
    static let showHideHotKey     = "hotkey.showHide"
    static let clickThroughHotKey = "hotkey.clickThrough"

    /// Registered at launch so plain `UserDefaults` reads (the AppDelegate's
    /// appliers) agree with the `@AppStorage` defaults above.
    static var registrationDefaults: [String: Any] {
        var d: [String: Any] = [
            panelOpacity.key: panelOpacity.defaultValue,
            editorFontSize.key: editorFontSize.defaultValue,
            theme.key: theme.defaultValue,
            alwaysOnTop.key: alwaysOnTop.defaultValue,
            hideFromCapture.key: hideFromCapture.defaultValue,
            clickThrough.key: clickThrough.defaultValue,
        ]
        d.merge(Shortcut.defaultShowHide.registrationDefaults(prefix: showHideHotKey)) { a, _ in a }
        d.merge(Shortcut.defaultClickThrough.registrationDefaults(prefix: clickThroughHotKey)) { a, _ in a }
        return d
    }
}
