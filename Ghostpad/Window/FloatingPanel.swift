//
//  FloatingPanel.swift
//  Ghostpad
//
//  Transparent, always-on-top NSPanel that hosts SwiftUI content. AppKit lives
//  here in the window layer only. The panel doesn't open and close — it
//  materializes and banishes: summon() fades + drifts in, banish() exhales out.
//

import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    /// Invoked when the user presses Esc anywhere in the panel (the banish
    /// gesture). Esc reaches us through the responder chain via
    /// cancelOperation(_:), which text views pass up rather than consume.
    var onCancel: (() -> Void)?

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
        self.hasShadow = false // AppDelegate turns this on when the panel is near-solid
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.contentView = NSHostingView(rootView: content)
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    // MARK: - Motion

    /// Materialize: fade in while drifting up ~8pt into place. The window
    /// ends exactly at its stored frame, so frame autosave is undisturbed.
    func summon() {
        guard !isVisible else {
            makeKeyAndOrderFront(nil)
            return
        }
        let target = frame
        setFrame(target.offsetBy(dx: 0, dy: -8), display: false)
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
            animator().setFrame(target, display: true)
        }
    }

    /// Banish: a quick exhale — faster than the summon, like a ghost startled.
    /// Fade only (no drift), so the stored frame never moves.
    func banish() {
        guard isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1
        })
    }
}
