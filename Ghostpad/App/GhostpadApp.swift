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
    /// Posted after the panel materializes, so the editor can take focus —
    /// summon-and-type with no click in between.
    static let ghostpadSummoned = Notification.Name("ghostpad.summoned")
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
    private var clickThroughItem: NSMenuItem?
    private var defaultsObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var settingsWindow: NSWindow?
    private var hotKeys: [String: GlobalHotKey] = [:]
    private var appliedHotKeys: [String: Shortcut] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep plain UserDefaults reads consistent with the @AppStorage defaults.
        UserDefaults.standard.register(defaults: AppSettings.registrationDefaults)

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
        panel.onCancel = { [weak self] in self?.hidePanel() } // Esc banishes
        applyWindowLevel()
        applyCaptureExclusion()
        applyClickThrough()
        applyMateriality()
        showPanel()

        setupStatusItem()
        applyHotKeys() // system-wide hotkeys, read from settings

        // React to settings changes (window flags + the global hotkeys).
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.applyWindowLevel()
                self?.applyCaptureExclusion()
                self?.applyClickThrough()
                self?.applyMateriality()
                self?.applyHotKeys()
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
        let onTop = UserDefaults.standard.bool(forKey: AppSettings.alwaysOnTop.key)
        panel?.level = onTop ? .floating : .normal
    }

    // .none excludes the panel from all screen recording/sharing/screenshots at
    // the OS level — so notes never leak into a screen share, no detection needed.
    private func applyCaptureExclusion() {
        let hidden = UserDefaults.standard.bool(forKey: AppSettings.hideFromCapture.key)
        panel?.sharingType = hidden ? .none : .readOnly
    }

    // Click-through: the panel ignores the mouse so clicks reach the app behind.
    // Recoverable from the global hotkey and the menu bar, never by clicking
    // the panel. The status icon flips too, so the state is glanceable even
    // when the panel is off-screen.
    private func applyClickThrough() {
        let phased = UserDefaults.standard.bool(forKey: AppSettings.clickThrough.key)
        panel?.ignoresMouseEvents = phased
        statusItem?.button?.image = statusImage(phased: phased)
    }

    private func statusImage(phased: Bool) -> NSImage? {
        let image = NSImage(
            systemSymbolName: phased ? "cursorarrow.slash" : "note.text",
            accessibilityDescription: phased ? "Ghostpad (click-through)" : "Ghostpad"
        )
        image?.isTemplate = true
        return image
    }

    // Materiality: a near-solid panel casts a real window shadow; a translucent
    // one floats shadowless. Guarded so opacity drags only pay on the crossing.
    private func applyMateriality() {
        guard let panel else { return }
        let solid = UserDefaults.standard.double(forKey: AppSettings.panelOpacity.key) >= 0.85
        if panel.hasShadow != solid {
            panel.hasShadow = solid
            panel.invalidateShadow()
        }
    }

    // Register (or re-register) the global hotkeys from settings. Guarded per
    // hotkey so unrelated defaults changes (e.g. opacity drags) don't churn them.
    private func applyHotKeys() {
        registerHotKey(AppSettings.showHideHotKey) { [weak self] in self?.togglePanel() }
        registerHotKey(AppSettings.clickThroughHotKey) { [weak self] in self?.toggleClickThrough() }
    }

    private func registerHotKey(_ prefix: String, action: @escaping () -> Void) {
        let shortcut = Shortcut.load(prefix: prefix)
        guard appliedHotKeys[prefix] != shortcut else { return }
        appliedHotKeys[prefix] = shortcut
        // Replacing the instance deinits the old one, unregistering it first.
        let registered = GlobalHotKey(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers, handler: action)
        hotKeys[prefix] = registered

        // The OS can refuse a combo another app owns. Don't fail silently:
        // record it so Settings can show "couldn't register" on the exact row.
        // (Guarded write — we're inside a defaults-change observer.)
        let failedKey = "\(prefix).failed"
        let failed = registered == nil
        if UserDefaults.standard.bool(forKey: failedKey) != failed {
            UserDefaults.standard.set(failed, forKey: failedKey)
        }
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = statusImage(
            phased: UserDefaults.standard.bool(forKey: AppSettings.clickThrough.key)
        )

        let menu = NSMenu()
        menu.delegate = self

        let toggle = NSMenuItem(title: "Hide Ghostpad", action: #selector(togglePanel), keyEquivalent: "")
        toggle.target = self
        toggleItem = toggle
        menu.addItem(toggle)

        let newNote = NSMenuItem(title: "New Note", action: #selector(newNote), keyEquivalent: "")
        newNote.target = self
        menu.addItem(newNote)

        let clickThrough = NSMenuItem(title: "Click-Through", action: #selector(toggleClickThrough), keyEquivalent: "")
        clickThrough.target = self
        clickThroughItem = clickThrough
        menu.addItem(clickThrough)

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

    /// Keep the toggle items' titles, state, and displayed shortcuts in sync.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let visible = panel?.isVisible ?? false
        toggleItem?.title = visible ? "Hide Ghostpad" : "Show Ghostpad"
        clickThroughItem?.state = UserDefaults.standard.bool(forKey: AppSettings.clickThrough.key) ? .on : .off

        if let toggleItem { mirrorHotKey(AppSettings.showHideHotKey, on: toggleItem) }
        if let clickThroughItem { mirrorHotKey(AppSettings.clickThroughHotKey, on: clickThroughItem) }
    }

    // Show a configured global hotkey as a menu key-equivalent when it's a
    // single letter/digit (otherwise leave it off the menu).
    private func mirrorHotKey(_ prefix: String, on item: NSMenuItem) {
        if let equivalent = Shortcut.load(prefix: prefix).menuKeyEquivalent {
            item.keyEquivalent = equivalent.key
            item.keyEquivalentModifierMask = equivalent.modifiers
        } else {
            item.keyEquivalent = ""
        }
    }

    @objc private func togglePanel() {
        guard let panel else { return }
        panel.isVisible ? hidePanel() : showPanel()
    }

    private func showPanel() {
        panel?.summon()
        // Let the editor take focus so summon-and-type needs no click.
        NotificationCenter.default.post(name: .ghostpadSummoned, object: nil)
    }

    private func hidePanel() {
        store.flush() // hiding is a natural save point
        panel?.banish()
    }

    @objc private func newNote() {
        store.create()
        showPanel()
    }

    @objc private func toggleClickThrough() {
        let new = !UserDefaults.standard.bool(forKey: AppSettings.clickThrough.key)
        UserDefaults.standard.set(new, forKey: AppSettings.clickThrough.key)
        // applyClickThrough() runs via the defaults observer.
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

    // Disk writes are debounced 500ms; quitting inside that window must not
    // lose the last edit.
    func applicationWillTerminate(_ notification: Notification) {
        store.flush()
    }

    // Red close button hides the panel to the menu bar instead of closing it.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hidePanel()
        return false
    }
}
