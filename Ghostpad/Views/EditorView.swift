//
//  EditorView.swift
//  Ghostpad
//
//  The floating panel's content: an optional note sidebar plus the editor.
//  Edits the active note via a direct binding into the NoteStore; opacity is
//  presentation state, persisted via @AppStorage.
//

import SwiftUI
import NotesCore

struct EditorView: View {
    @ObservedObject var store: NoteStore
    @AppStorage("panelOpacity") private var opacity: Double = 0.6

    @State private var showSidebar = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
                sidebar
                    .frame(width: 160)
                    .background(sidebarBackground)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1)
                    }
            }
            editorColumn
                .background(Color.black.opacity(opacity))
        }
        .cornerRadius(10)
        .background(shortcutButtons)
        .alert("Delete note?", isPresented: $showingDeleteConfirm, presenting: store.activeNote) { note in
            Button("Delete", role: .destructive) { store.delete(id: note.id) }
            Button("Cancel", role: .cancel) {}
        } message: { note in
            Text("“\(note.title)” will be permanently deleted.")
        }
    }

    // MARK: - Editor

    private var editorColumn: some View {
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

    // MARK: - Sidebar

    private var sortedNotes: [Note] {
        store.notes.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            Button(action: { store.create() }) {
                HStack {
                    Text("New note")
                    Spacer()
                    Text("⌘N").opacity(0.4)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedNotes) { note in
                        noteRow(note)
                    }
                }
            }
        }
        .font(.system(size: 13))
        .foregroundColor(.white)
    }

    private func noteRow(_ note: Note) -> some View {
        let isActive = note.id == store.activeNoteID
        return Text(note.title)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color.white.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { store.setActive(id: note.id) }
    }

    private var sidebarBackground: some View {
        ZStack {
            Color.black.opacity(opacity)
            Color.white.opacity(0.06)
        }
    }

    // MARK: - Shortcuts

    private var shortcutButtons: some View {
        ZStack {
            Button("") { showSidebar.toggle() }
                .keyboardShortcut("b", modifiers: .command)
            Button("") { store.create() }
                .keyboardShortcut("n", modifiers: .command)
            // ⌘⌫ deletes the selected note only while the sidebar is open,
            // so it doesn't shadow delete-to-line-start in the editor.
            if showSidebar {
                Button("") { if store.activeNote != nil { showingDeleteConfirm = true } }
                    .keyboardShortcut(.delete, modifiers: .command)
            }
            Button("") { nudge(+0.05) }
                .keyboardShortcut(.upArrow, modifiers: .command)
            Button("") { nudge(-0.05) }
                .keyboardShortcut(.downArrow, modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
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
