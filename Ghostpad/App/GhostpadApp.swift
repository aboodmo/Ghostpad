//
//  GhostpadApp.swift
//  Ghostpad
//
//  App entry point and AppDelegate. Owns the NoteStore and wires the floating
//  panel to its content.
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
final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel?
    private let store = NoteStore(storage: FileNoteStorage())

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load all notes; if none exist, create one. Activate the first.
        store.loadAll()
        if store.notes.isEmpty {
            store.create()
        } else {
            store.activeNoteID = store.notes.first?.id
        }

        panel = FloatingPanel(
            contentRect: NSRect(x: 200, y: 200, width: 400, height: 500),
            content: EditorView(store: store)
        )
        panel?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
