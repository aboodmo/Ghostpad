//
//  GhostpadApp.swift
//  Ghostpad
//
//  Created by Abdelrahman Mohammad on 6/4/26.
//

import SwiftUI
import AppKit

@main
struct TransparentNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }  // placeholder so SwiftUI is happy
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = EditorView()
        panel = FloatingPanel(
            contentRect: NSRect(x: 200, y: 200, width: 400, height: 500),
            content: contentView
        )
        panel?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

class FloatingPanel: NSPanel {
    init<Content: View>(contentRect: NSRect, content: Content) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.contentView = NSHostingView(rootView: content)
    }

    override var canBecomeKey: Bool { true }
}

struct EditorView: View {
    @State private var text: String = "Type here..."
    @State private var opacity: Double = 0.6

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 16))
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(Color.black.opacity(opacity))
            .foregroundColor(.white)
            .cornerRadius(10)
    }
}
