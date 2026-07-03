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
