//
//  SettingsView.swift
//  Ghostpad
//
//  Contents of the SwiftUI Settings scene (⌘,). Values are stored via
//  @AppStorage; the editor and panel read the same keys and react live.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("panelOpacity") private var opacity: Double = 0.6
    @AppStorage("editorFontSize") private var fontSize: Double = 15
    @AppStorage("alwaysOnTop") private var alwaysOnTop: Bool = true

    var body: some View {
        Form {
            Section("Appearance") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Opacity: \(Int((opacity * 100).rounded()))%")
                    Slider(value: $opacity, in: 0.1...1.0)
                }
                Stepper("Editor font size: \(Int(fontSize)) pt",
                        value: $fontSize, in: 10...28, step: 1)
            }

            Section("Window") {
                Toggle("Keep window always on top", isOn: $alwaysOnTop)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 240)
    }
}

#Preview {
    SettingsView()
}
