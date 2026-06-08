//
//  SettingsView.swift
//  Ghostpad
//
//  Contents of the Settings window (⌘,). Styled to match the Vapor panel —
//  the active theme's own background/text/accent, a serif title, grouped cards
//  with an icon per row — so it no longer clashes with the floating note.
//  Values are stored via @AppStorage; the editor and panel read the same keys
//  and react live.
//

import SwiftUI
import AppKit
import Carbon.HIToolbox

struct SettingsView: View {
    @AppStorage("panelOpacity") private var opacity: Double = 0.6
    @AppStorage("editorFontSize") private var fontSize: Double = 15
    @AppStorage("alwaysOnTop") private var alwaysOnTop: Bool = true
    @AppStorage("hideFromCapture") private var hideFromCapture: Bool = true
    @AppStorage("clickThrough") private var clickThrough: Bool = false
    @AppStorage("theme") private var themeRaw: String = Theme.vapor.rawValue

    // The configurable global hotkeys, stored as their parts.
    @AppStorage("hotkey.showHide.keyCode") private var hkKeyCode: Int = Shortcut.defaultShowHide.keyCode
    @AppStorage("hotkey.showHide.modifiers") private var hkModifiers: Int = Shortcut.defaultShowHide.modifiers
    @AppStorage("hotkey.showHide.label") private var hkLabel: String = Shortcut.defaultShowHide.label

    @AppStorage("hotkey.clickThrough.keyCode") private var ctKeyCode: Int = Shortcut.defaultClickThrough.keyCode
    @AppStorage("hotkey.clickThrough.modifiers") private var ctModifiers: Int = Shortcut.defaultClickThrough.modifiers
    @AppStorage("hotkey.clickThrough.label") private var ctLabel: String = Shortcut.defaultClickThrough.label

    private var theme: Theme { Theme(rawValue: themeRaw) ?? .vapor }

    // The built-in editor shortcuts — shown read-only for reference.
    private let builtIns: [(String, Shortcut)] = [
        ("Toggle Sidebar", Shortcut(keyCode: kVK_ANSI_B, modifiers: cmdKey, label: "B")),
        ("New Note",       Shortcut(keyCode: kVK_ANSI_N, modifiers: cmdKey, label: "N")),
        ("Delete Note",    Shortcut(keyCode: kVK_Delete, modifiers: cmdKey, label: "⌫")),
        ("Opacity Up",     Shortcut(keyCode: kVK_UpArrow, modifiers: cmdKey, label: "↑")),
        ("Opacity Down",   Shortcut(keyCode: kVK_DownArrow, modifiers: cmdKey, label: "↓")),
    ]

    private var showHide: Binding<Shortcut> {
        Binding(
            get: { Shortcut(keyCode: hkKeyCode, modifiers: hkModifiers, label: hkLabel) },
            set: { hkKeyCode = $0.keyCode; hkModifiers = $0.modifiers; hkLabel = $0.label }
        )
    }

    private var clickThroughKey: Binding<Shortcut> {
        Binding(
            get: { Shortcut(keyCode: ctKeyCode, modifiers: ctModifiers, label: ctLabel) },
            set: { ctKeyCode = $0.keyCode; ctModifiers = $0.modifiers; ctLabel = $0.label }
        )
    }

    // Warn (but allow) on a likely conflict: another Ghostpad hotkey, a known
    // macOS system shortcut, or a built-in editor shortcut.
    private func warning(for s: Shortcut, against other: Shortcut) -> String? {
        if s.matches(other) { return "Same as another Ghostpad hotkey." }
        if s.conflictsWithSystemShortcut { return "May conflict with a macOS system shortcut." }
        if builtIns.contains(where: { $0.1.matches(s) }) { return "Overlaps a built-in editor shortcut." }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.system(size: 22, weight: .semibold, design: .serif))

                card("Appearance") {
                    row("paintpalette", "Theme") {
                        Picker("", selection: $themeRaw) {
                            ForEach(Theme.allCases) { t in Text(t.name).tag(t.rawValue) }
                        }
                        .labelsHidden()
                        .frame(width: 168)
                    }
                    divider
                    row("circle.lefthalf.filled", "Opacity") {
                        HStack(spacing: 10) {
                            Slider(value: $opacity, in: 0.1...1.0).frame(width: 140)
                            Text("\(Int((opacity * 100).rounded()))%")
                                .font(.system(size: 12, design: .rounded).monospacedDigit())
                                .foregroundColor(theme.text.opacity(0.55))
                                .frame(width: 38, alignment: .trailing)
                        }
                    }
                    divider
                    row("textformat.size", "Editor text size") {
                        Stepper("\(Int(fontSize)) pt", value: $fontSize, in: 10...28, step: 1)
                            .frame(width: 116)
                    }
                }

                shortcutsCard

                card("Window") {
                    row("pin", "Keep always on top") {
                        Toggle("", isOn: $alwaysOnTop)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    divider
                    row("eye.slash", "Hide from screen sharing") {
                        Toggle("", isOn: $hideFromCapture)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    divider
                    row("cursorarrow.rays", "Click-through (ignore mouse)") {
                        Toggle("", isOn: $clickThrough)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                footer
            }
            .padding(26)
        }
        .frame(width: 460, height: 580)
        .background(theme.background)
        .foregroundColor(theme.text)
        .tint(theme.accent)
        .preferredColorScheme(theme.isDark ? .dark : .light)
    }

    // MARK: - Shortcuts

    private var shortcutsCard: some View {
        card("Shortcuts") {
            hotKeyRow("macwindow.on.rectangle", "Show / Hide Ghostpad",
                      binding: showHide, against: clickThroughKey.wrappedValue)
            divider
            hotKeyRow("cursorarrow.rays", "Toggle Click-Through",
                      binding: clickThroughKey, against: showHide.wrappedValue)

            ForEach(builtIns, id: \.0) { name, sc in
                divider
                builtInRow(name, sc.display)
            }

            divider
            HStack {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13))
                    .foregroundColor(theme.text.opacity(0.5))
                    .frame(width: 18)
                Text("Reset to default").font(.system(size: 13))
                Spacer(minLength: 16)
                Button("Reset") {
                    showHide.wrappedValue = .defaultShowHide
                    clickThroughKey.wrappedValue = .defaultClickThrough
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
    }

    @ViewBuilder
    private func hotKeyRow(_ icon: String, _ title: String,
                           binding: Binding<Shortcut>, against other: Shortcut) -> some View {
        row(icon, title) {
            ShortcutRecorder(shortcut: binding, theme: theme)
        }
        if let warning = warning(for: binding.wrappedValue, against: other) {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                Text(warning)
                    .font(.system(size: 11))
                    .foregroundColor(theme.text.opacity(0.65))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
    }

    private func builtInRow(_ name: String, _ combo: String) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(theme.text.opacity(0.6))
            Spacer(minLength: 16)
            Text(combo)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(theme.text.opacity(0.4))
        }
        .padding(.leading, 44)
        .padding(.trailing, 14)
        .padding(.vertical, 9)
    }

    // MARK: - Building blocks

    /// A titled, rounded, hairline-bordered group of rows.
    private func card<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1.3)
                .foregroundColor(theme.text.opacity(0.45))
            VStack(spacing: 0) { content() }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.text.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.text.opacity(0.08), lineWidth: 1)
                )
        }
    }

    private func row<Control: View>(
        _ icon: String, _ label: String, @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(theme.text.opacity(0.5))
                .frame(width: 18)
            Text(label).font(.system(size: 13))
            Spacer(minLength: 16)
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // Hairline between rows, inset to start under the label (past the icon).
    private var divider: some View {
        Rectangle()
            .fill(theme.text.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 44)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Text("Ghostpad\(versionSuffix)")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(theme.text.opacity(0.35))
        }
    }

    private var versionSuffix: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return v.map { " \($0)" } ?? ""
    }
}

// MARK: - Shortcut recorder

/// Click to start recording, then press a combo. Swallows the keystroke so it
/// doesn't trigger anything else, requires a real modifier, and Esc cancels.
private struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut
    var theme: Theme

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button { recording.toggle() } label: {
            Text(recording ? "Press keys…" : shortcut.display)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(recording ? theme.accent : theme.text)
                .frame(minWidth: 84)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(theme.text.opacity(recording ? 0.16 : 0.08))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(recording ? theme.accent : .clear, lineWidth: 1)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onChange(of: recording) { _, rec in rec ? start() : stop() }
        .onDisappear(perform: stop)
    }

    private func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if Int(event.keyCode) == kVK_Escape {
                recording = false
                return nil
            }
            let candidate = Shortcut(
                keyCode: Int(event.keyCode),
                modifiers: carbonModifiers(event.modifierFlags),
                label: keyLabel(event)
            )
            // Ignore presses without a real modifier; keep recording.
            if candidate.hasRequiredModifier {
                shortcut = candidate
                recording = false
            }
            return nil // swallow so nothing else fires
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if flags.contains(.command) { m |= cmdKey }
        if flags.contains(.option)  { m |= optionKey }
        if flags.contains(.control) { m |= controlKey }
        if flags.contains(.shift)   { m |= shiftKey }
        return m
    }

    private func keyLabel(_ event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space:      return "Space"
        case kVK_Return:     return "↩"
        case kVK_Tab:        return "⇥"
        case kVK_Delete:     return "⌫"
        case kVK_LeftArrow:  return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow:    return "↑"
        case kVK_DownArrow:  return "↓"
        default:
            let s = event.charactersIgnoringModifiers ?? ""
            return s.isEmpty ? "Key \(event.keyCode)" : s.uppercased()
        }
    }
}

#Preview {
    SettingsView()
}
