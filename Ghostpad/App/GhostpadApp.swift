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

@main
struct GhostpadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }  // placeholder so SwiftUI is happy
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let store = NoteStore(storage: FileNoteStorage())
    private var panel: FloatingPanel?
    private var statusItem: NSStatusItem?
    private var toggleItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        panel.makeKeyAndOrderFront(nil)

        setupStatusItem()
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
