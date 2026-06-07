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

struct SettingsView: View {
    @AppStorage("panelOpacity") private var opacity: Double = 0.6
    @AppStorage("editorFontSize") private var fontSize: Double = 15
    @AppStorage("alwaysOnTop") private var alwaysOnTop: Bool = true
    @AppStorage("theme") private var themeRaw: String = Theme.vapor.rawValue

    private var theme: Theme { Theme(rawValue: themeRaw) ?? .vapor }

    var body: some View {
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

            card("Window") {
                row("pin", "Keep always on top") {
                    Toggle("", isOn: $alwaysOnTop)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Spacer(minLength: 0)
            footer
        }
        .padding(26)
        .frame(width: 440, height: 400)
        .background(theme.background)
        .foregroundColor(theme.text)
        .tint(theme.accent)
        .preferredColorScheme(theme.isDark ? .dark : .light)
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

#Preview {
    SettingsView()
}
