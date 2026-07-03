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
import ServiceManagement

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

    // Set by the AppDelegate when the OS refuses a combo (owned by another app).
    @AppStorage("hotkey.showHide.failed") private var hkFailed: Bool = false
    @AppStorage("hotkey.clickThrough.failed") private var ctFailed: Bool = false

    // Login-item state lives with the OS (SMAppService), not in defaults.
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var theme: Theme { Theme(rawValue: themeRaw) ?? .vapor }

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
        if Shortcut.builtIns.contains(where: { $0.shortcut.matches(s) }) { return "Overlaps a built-in editor shortcut." }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.system(size: 22, weight: .semibold, design: .serif))

                card("Appearance") {
                    themeGrid
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

                card("Behavior") {
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
                    divider
                    row("power", "Launch at login") {
                        Toggle("", isOn: $launchAtLogin)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                footer
            }
            .padding(26)
        }
        .frame(width: 460, height: 620)
        .onChange(of: launchAtLogin) { _, wantOn in
            // Registration can fail (e.g. unsigned dev builds); reflect reality.
            do {
                wantOn ? try SMAppService.mainApp.register()
                       : try SMAppService.mainApp.unregister()
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
        .background(theme.background)
        .foregroundColor(theme.text)
        .tint(theme.accent)
        .preferredColorScheme(theme.isDark ? .dark : .light)
    }

    // MARK: - Theme swatches

    /// Every theme shown as a live tile — its background, its text ("Aa" in
    /// the editor serif), its accent dot — instead of a list of names. The
    /// selected tile rings itself in its own accent.
    private var themeGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
            ForEach(Theme.allCases) { t in
                themeTile(t)
            }
        }
        .padding(14)
    }

    private func themeTile(_ t: Theme) -> some View {
        let selected = t.rawValue == themeRaw
        return Button { themeRaw = t.rawValue } label: {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(t.background)
                    HStack(spacing: 4) {
                        Text("Aa")
                            .font(.system(size: 13, weight: .semibold, design: .serif))
                            .foregroundColor(t.text)
                        Circle()
                            .fill(t.accent)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            selected ? t.accent : theme.text.opacity(0.15),
                            lineWidth: selected ? 2 : 1
                        )
                )
                Text(t.name)
                    .font(.system(size: 9.5))
                    .foregroundColor(theme.text.opacity(selected ? 0.9 : 0.5))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(t.name)
    }

    // MARK: - Shortcuts

    private var shortcutsCard: some View {
        card("Shortcuts") {
            hotKeyRow("macwindow.on.rectangle", "Show / Hide Ghostpad",
                      binding: showHide, against: clickThroughKey.wrappedValue, failed: hkFailed)
            divider
            hotKeyRow("cursorarrow.rays", "Toggle Click-Through",
                      binding: clickThroughKey, against: showHide.wrappedValue, failed: ctFailed)

            ForEach(Shortcut.builtIns, id: \.name) { name, sc in
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
                           binding: Binding<Shortcut>, against other: Shortcut,
                           failed: Bool) -> some View {
        row(icon, title) {
            ShortcutRecorder(shortcut: binding, theme: theme)
        }
        if failed {
            // Registration was refused — this is an error, not a maybe.
            notice("xmark.octagon.fill", .red,
                   "Couldn't register — another app owns this shortcut. Pick a different one.")
        } else if let warning = warning(for: binding.wrappedValue, against: other) {
            notice("exclamationmark.triangle.fill", .orange, warning)
        }
    }

    private func notice(_ icon: String, _ color: Color, _ text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(theme.text.opacity(0.65))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
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
            if Shortcut.isEscape(event) {
                recording = false
                return nil
            }
            let candidate = Shortcut(event: event)
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
}

#Preview {
    SettingsView()
}
