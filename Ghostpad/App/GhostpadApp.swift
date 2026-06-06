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

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep UserDefaults reads consistent with the @AppStorage defaults.
        UserDefaults.standard.register(defaults: [
            "panelOpacity": 0.6,
            "editorFontSize": 15.0,
            "alwaysOnTop": true,
            "theme": Theme.vapor.rawValue
        ])

        // Load all notes; if none exist, create one. Activate the first.
        store.loadAll()
        if store.notes.isEmpty {
            store.create()
        } else {
            store.activeNoteID = store.notes.first?.id
        }

        let panel = FloatingPanel(
            contentRect: NSRect(x: 200, y: 200, width: 400, height: 500),
            content: EditorView(store: store)
        )
        panel.delegate = self
        self.panel = panel
        applyWindowLevel()
        panel.makeKeyAndOrderFront(nil)

        setupStatusItem()

        // React to the "always on top" setting changing in the Settings window.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyWindowLevel() }
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

    /// Keep the toggle item's title in sync with the panel's visibility.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let visible = panel?.isVisible ?? false
        toggleItem?.title = visible ? "Hide Ghostpad" : "Show Ghostpad"
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
