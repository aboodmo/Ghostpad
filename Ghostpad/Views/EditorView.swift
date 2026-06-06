//
//  EditorView.swift
//  Ghostpad
//
//  The floating panel's content. Edits the active note via a direct binding
//  into the NoteStore; opacity is presentation state, persisted via @AppStorage.
//

import SwiftUI
import NotesCore

struct EditorView: View {
    @ObservedObject var store: NoteStore
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

            TextEditor(text: activeBody)
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

    /// Two-way binding into the active note's body, routed through the store.
    private var activeBody: Binding<String> {
        Binding(
            get: { store.activeNote?.body ?? "" },
            set: { newValue in
                if let id = store.activeNoteID {
                    store.update(id: id, body: newValue)
                }
            }
        )
    }

    private func nudge(_ delta: Double) {
        opacity = min(1.0, max(0.1, opacity + delta))
    }
}

#Preview {
    let store = NoteStore(storage: InMemoryNoteStorage(seed: [
        Note(body: "First note\nwith a second line"),
        Note(body: "Another note")
    ]))
    store.loadAll()
    store.activeNoteID = store.notes.first?.id
    return EditorView(store: store)
}
