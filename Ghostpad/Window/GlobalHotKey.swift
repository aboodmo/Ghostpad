//
//  GlobalHotKey.swift
//  Ghostpad
//
//  A single system-wide hotkey via Carbon — no dependency and no Accessibility
//  permission required (unlike NSEvent global monitors). Window-layer only;
//  never imported by model code.
//

import Foundation
import Carbon.HIToolbox

final class GlobalHotKey {
    // Maps a registered hotkey's id to its handler. One process-wide Carbon
    // event handler dispatches through this.
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    private var ref: EventHotKeyRef?
    private let id: UInt32

    /// `keyCode` is a Carbon virtual key (e.g. `kVK_ANSI_G`); `modifiers` is a
    /// Carbon modifier mask (e.g. `cmdKey | optionKey`). Returns nil if the
    /// system refuses the registration (e.g. the combo is already taken).
    init?(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        GlobalHotKey.installHandlerIfNeeded()
        id = GlobalHotKey.nextID
        GlobalHotKey.nextID += 1
        GlobalHotKey.handlers[id] = handler

        let hotKeyID = EventHotKeyID(signature: OSType(0x47485054), id: id) // 'GHPT'
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr else {
            GlobalHotKey.handlers[id] = nil
            return nil
        }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        GlobalHotKey.handlers[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var type = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                guard let event else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &hkID
                )
                if let handler = GlobalHotKey.handlers[hkID.id] {
                    DispatchQueue.main.async(execute: handler)
                }
                return noErr
            },
            1, &type, nil, nil
        )
    }
}

// MARK: - Shortcut model

/// A hotkey combo: a Carbon virtual key code, a Carbon modifier mask, and a
/// display label for the key. Used by both the AppDelegate registration and the
/// Settings recorder.
struct Shortcut: Equatable {
    var keyCode: Int
    var modifiers: Int   // Carbon mask: cmdKey | optionKey | controlKey | shiftKey
    var label: String    // display label for the key, e.g. "G", "Space", "←"

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
