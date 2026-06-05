//
//  EditorView.swift
//  Ghostpad
//
//  The floating panel's content. Binds to EditorViewModel for the note text;
//  opacity is pure presentation state, persisted via @AppStorage.
//

import SwiftUI

struct EditorView: View {
    @StateObject private var viewModel = EditorViewModel()
    @AppStorage("panelOpacity") private var opacity: Double = 0.6

    var body: some View {
        VStack(spacing: 0) {
            Slider(value: $opacity, in: 0.1...1.0)
                .controlSize(.small)
                .tint(.white)
                .opacity(0.4)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            TextEditor(text: $viewModel.note.body)
                .font(.system(size: 16))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .foregroundColor(.white)
        }
        .background(Color.black.opacity(opacity))
        .cornerRadius(10)
        .background(
            // Invisible buttons that carry the keyboard shortcuts.
            ZStack {
                Button("") { nudge(+0.05) }
                    .keyboardShortcut(.upArrow, modifiers: .command)
                Button("") { nudge(-0.05) }
                    .keyboardShortcut(.downArrow, modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        )
    }

    private func nudge(_ delta: Double) {
        opacity = min(1.0, max(0.1, opacity + delta))
    }
}

#Preview {
    EditorView()
}
