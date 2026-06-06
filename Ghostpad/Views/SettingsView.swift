//
//  SettingsView.swift
//  Ghostpad
//
//  Contents of the Settings window (⌘,). Styled to match the Vapor panel —
//  the active theme's own background/text/accent, a serif title, and quiet
//  section headers — so it no longer clashes with the floating note. Values are
//  stored via @AppStorage; the editor and panel read the same keys and react live.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("panelOpacity") private var opacity: Double = 0.6
    @AppStorage("editorFontSize") private var fontSize: Double = 15
    @AppStorage("alwaysOnTop") private var alwaysOnTop: Bool = true
    @AppStorage("theme") private var themeRaw: String = Theme.vapor.rawValue

    private var theme: Theme { Theme(rawValue: themeRaw) ?? .vapor }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Settings")
                .font(.system(size: 22, weight: .semibold, design: .serif))

            section("Appearance") {
                row("Theme") {
                    Picker("", selection: $themeRaw) {
                        ForEach(Theme.allCases) { t in Text(t.name).tag(t.rawValue) }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }
                row("Opacity") {
                    HStack(spacing: 10) {
                        Slider(value: $opacity, in: 0.1...1.0).frame(width: 150)
                        Text("\(Int((opacity * 100).rounded()))%")
                            .font(.system(size: 12, design: .rounded).monospacedDigit())
                            .foregroundColor(theme.text.opacity(0.55))
                            .frame(width: 38, alignment: .trailing)
                    }
                }
                row("Editor text size") {
                    Stepper("\(Int(fontSize)) pt", value: $fontSize, in: 10...28, step: 1)
                        .frame(width: 120)
                }
            }

            section("Window") {
                row("Keep always on top") {
                    Toggle("", isOn: $alwaysOnTop)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(width: 430, height: 360)
        .background(theme.background)
        .foregroundColor(theme.text)
        .tint(theme.accent)
        .preferredColorScheme(theme.isDark ? .dark : .light)
    }

    // MARK: - Building blocks

    private func section<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1.3)
                .foregroundColor(theme.text.opacity(0.45))
            VStack(spacing: 0) { content() }
        }
    }

    private func row<Control: View>(
        _ label: String, @ViewBuilder control: () -> Control
    ) -> some View {
        HStack {
            Text(label).font(.system(size: 13))
            Spacer(minLength: 16)
            control()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.text.opacity(0.07)).frame(height: 1)
        }
    }
}

#Preview {
    SettingsView()
}
