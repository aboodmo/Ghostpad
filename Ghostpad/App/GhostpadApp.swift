//
//  GhostpadApp.swift
//  Ghostpad
//
//  App entry point and AppDelegate. Owns the NoteStore, the floating panel, and
//  the menu bar status item. The app is an agent (LSUIElement, no Dock icon) and
//  lives in the menu bar; closing the panel hides it rather than quitting.
//

import SwiftUI
import AppKit
import Carbon.HIToolbox
import NotesCore

extension Notification.Name {
    /// Posted by in-app UI (e.g. the toolbar gear) to open the Settings window.
    static let ghostpadOpenSettings = Notification.Name("ghostpad.openSettings")
}

@main
struct GhostpadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The Settings UI is shown in an AppKit-managed window (see AppDelegate),
        // not the SwiftUI Settings scene, so we can control its window level and
        // open it programmatically from the menu bar.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let store = NoteStore(storage: FileNoteStorage())
    private var panel: FloatingPanel?
    private var statusItem: NSStatusItem?
    private var toggleItem: NSMenuItem?
    private var defaultsObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var settingsWindow: NSWindow?
    private var showHideHotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep UserDefaults reads consistent with the @AppStorage defaults.
        UserDefaults.standard.register(defaults: [
            "panelOpacity": 0.6,
            "editorFontSize": 15.0,
            "alwaysOnTop": true,
            "theme": Theme.vapor.rawValue,
            "hotkey.showHide.keyCode": Shortcut.defaultShowHide.keyCode,
            "hotkey.showHide.modifiers": Shortcut.defaultShowHide.modifiers,
            "hotkey.showHide.label": Shortcut.defaultShowHide.label
        ])

        // Load all notes; if none exist, create one. Activate the first.
        store.loadAll()
        if store.notes.isEmpty {
            store.create()
        } else {
            store.activeNoteID = store.notes.first?.id
        }

        let panel = FloatingPanel(
            contentRect: NSRect(x: 200, y: 200, width: 760, height: 640),
            content: EditorView(store: store, showSidebar: true)
        )
        panel.delegate = self
        self.panel = panel
        // Remember the user's size/position across launches; the contentRect
        // above is only the first-run default. setFrameUsingName restores a
        // saved frame (no-op on first run); setFrameAutosaveName keeps it saved.
        panel.setFrameUsingName("GhostpadPanel")
        panel.setFrameAutosaveName("GhostpadPanel")
        applyWindowLevel()
        panel.makeKeyAndOrderFront(nil)

        setupStatusItem()
        applyHotKey() // system-wide show/hide hotkey, read from settings

        // React to settings changes (always-on-top, and the show/hide hotkey).
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.applyWindowLevel()
                self?.applyHotKey()
            }
        }

        // In-app "Settings" gear routes here so the window-raising logic runs.
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .ghostpadOpenSettings, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.openSettings() }
        }
    }

    private func applyWindowLevel() {
        let onTop = UserDefaults.standard.bool(forKey: "alwaysOnTop")
        panel?.level = onTop ? .floating : .normal
    }

    // Register (or re-register) the global show/hide hotkey from settings.
    // Guarded so unrelated defaults changes (e.g. opacity drags) don't churn it.
    private var appliedHotKeyCode = Int.min
    private var appliedHotKeyModifiers = Int.min
    private func applyHotKey() {
        let keyCode = UserDefaults.standard.integer(forKey: "hotkey.showHide.keyCode")
        let modifiers = UserDefaults.standard.integer(forKey: "hotkey.showHide.modifiers")
        guard keyCode != appliedHotKeyCode || modifiers != appliedHotKeyModifiers else { return }
        appliedHotKeyCode = keyCode
        appliedHotKeyModifiers = modifiers
        // Replacing the instance deinits the old one, unregistering it first.
        showHideHotKey = GlobalHotKey(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            self?.togglePanel()
        }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Ghostpad")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.delegate = self

        let toggle = NSMenuItem(title: "Hide Ghostpad", action: #selector(togglePanel), keyEquivalent: "")
        toggle.target = self
        toggleItem = toggle
        menu.addItem(toggle)

        let newNote = NSMenuItem(title: "New Note", action: #selector(newNote), keyEquivalent: "")
        newNote.target = self
        menu.addItem(newNote)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Ghostpad", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    /// Keep the toggle item's title (and displayed shortcut) in sync.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let visible = panel?.isVisible ?? false
        toggleItem?.title = visible ? "Hide Ghostpad" : "Show Ghostpad"

        // Mirror the configured global hotkey as the menu's key equivalent when
        // it's a single letter/digit (otherwise just leave it off the menu).
        let label = UserDefaults.standard.string(forKey: "hotkey.showHide.label") ?? ""
        if label.count == 1, let c = label.lowercased().first, c.isLetter || c.isNumber {
            toggleItem?.keyEquivalent = String(c)
            let mods = UserDefaults.standard.integer(forKey: "hotkey.showHide.modifiers")
            var mask: NSEvent.ModifierFlags = []
            if mods & cmdKey != 0 { mask.insert(.command) }
            if mods & optionKey != 0 { mask.insert(.option) }
            if mods & controlKey != 0 { mask.insert(.control) }
            if mods & shiftKey != 0 { mask.insert(.shift) }
            toggleItem?.keyEquivalentModifierMask = mask
        } else {
            toggleItem?.keyEquivalent = ""
        }
    }

    @objc private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func newNote() {
        store.create()
        panel?.makeKeyAndOrderFront(nil)
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)

        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "Ghostpad Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        // Sit just above the always-on-top panel so it's never hidden behind it.
        settingsWindow?.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Lifecycle

    // Menu bar app: stay alive when the panel is hidden/closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // Red close button hides the panel to the menu bar instead of closing it.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        panel?.orderOut(nil)
        return false
    }
}
