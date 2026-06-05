//
//  FloatingPanel.swift
//  Ghostpad
//
//  Transparent, always-on-top NSPanel that hosts SwiftUI content. AppKit lives
//  here in the window layer only.
//

import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
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
