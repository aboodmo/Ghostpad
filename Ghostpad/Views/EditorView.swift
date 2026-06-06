//
//  EditorView.swift
//  Ghostpad
//
//  The floating panel's content: a top toolbar (sidebar toggle sits beside the
//  traffic lights, à la Apple Notes), an optional note sidebar, and the editor.
//  Edits the active note via a direct binding into the NoteStore; opacity and
//  theme are presentation state, persisted via @AppStorage.
//

import SwiftUI
import NotesCore

struct EditorView: View {
    @ObservedObject var store: NoteStore
    @AppStorage("panelOpacity") private var opacity: Double = 0.6
    @AppStorage("editorFontSize") private var fontSize: Double = 15
    @AppStorage("theme") private var themeRaw: String = Theme.vapor.rawValue

    @State private var showSidebar: Bool
    @State private var notePendingDelete: Note?

    init(store: NoteStore, showSidebar: Bool = false) {
        _store = ObservedObject(wrappedValue: store)
        _showSidebar = State(initialValue: showSidebar)
    }

    private let cornerRadius: CGFloat = 16
    private let sidebarWidth: CGFloat = 184

    private var theme: Theme { Theme(rawValue: themeRaw) ?? .vapor }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            hairline
            HStack(spacing: 0) {
                if showSidebar {
                    sidebar
                        .frame(width: sidebarWidth)
                        .background(sidebarBackground)
                        .overlay(alignment: .trailing) { vHairline }
                }
                editor
            }
        }
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(theme.text.opacity(0.10), lineWidth: 1)
        )
        .background(shortcutButtons)
        .alert(
            "Delete note?",
            isPresented: Binding(
                get: { notePendingDelete != nil },
                set: { if !$0 { notePendingDelete = nil } }
            ),
            presenting: notePendingDelete
        ) { note in
            Button("Delete", role: .destructive) { store.delete(id: note.id) }
            Button("Cancel", role: .cancel) {}
        } message: { note in
            Text("“\(note.title)” will be permanently deleted.")
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            toolbarButton(systemName: "sidebar.left", help: "Toggle Sidebar (⌘B)") {
                showSidebar.toggle()
            }
            .keyboardShortcut("b", modifiers: .command)

            Spacer(minLength: 8)

            Slider(value: $opacity, in: 0.1...1.0)
                .controlSize(.mini)
                .tint(theme.text)
                .frame(width: 64)
                .opacity(0.55)

            toolbarButton(systemName: "gearshape", help: "Settings (⌘,)") {
                NotificationCenter.default.post(name: .ghostpadOpenSettings, object: nil)
            }

            toolbarButton(systemName: "square.and.pencil", help: "New Note (⌘N)") {
                store.create()
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        // Leave room on the left for the window's traffic-light buttons.
        .padding(.leading, 76)
        .padding(.trailing, 12)
        .frame(height: 32)
        .foregroundColor(theme.text.opacity(0.85))
    }

    private func toolbarButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Editor

    private var editor: some View {
        TextEditor(text: activeBody)
            .font(.system(size: fontSize, design: .serif))
            .lineSpacing(5)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .foregroundColor(theme.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // Pinned first, then unpinned — each group most-recently-modified first.
    private var sortedNotes: [Note] {
        store.notes.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.modifiedAt > b.modifiedAt
        }
    }

    private var sidebar: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(sortedNotes) { note in
                    noteRow(note)
                }
            }
            .padding(6)
        }
    }

    private func noteRow(_ note: Note) -> some View {
        let isActive = note.id == store.activeNoteID
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                if note.isPinned {
                    Text("◆").font(.system(size: 7)).opacity(0.6)
                }
                Text(note.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Text(snippet(of: note))
                .font(.system(size: 11))
                .foregroundColor(theme.text.opacity(0.5))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? theme.text.opacity(0.16) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { store.setActive(id: note.id) }
        .contextMenu {
            Button(note.isPinned ? "Unpin" : "Pin") {
                store.setPinned(!note.isPinned, id: note.id)
            }
            Button("Delete", role: .destructive) { notePendingDelete = note }
        }
        .foregroundColor(theme.text)
    }

    /// First body line after the title line, used as the row's preview.
    private func snippet(of note: Note) -> String {
        var sawTitle = false
        for raw in note.body.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if !sawTitle { sawTitle = true; continue }
            return line
        }
        return "No additional text"
    }

    // The whole panel already carries the blur + tint; the sidebar just adds a
    // faint veil so it reads as a distinct plane.
    private var sidebarBackground: some View {
        theme.text.opacity(0.04)
    }

    // MARK: - Decorations

    /// Behind-window blur with the theme tint on top; the tint follows opacity
    /// while the blur stays, keeping text legible over a busy background.
    private var panelBackground: some View {
        ZStack {
            VisualEffectBackground()
            theme.background.opacity(opacity)
        }
    }

    private var hairline: some View {
        Rectangle().fill(theme.text.opacity(0.08)).frame(height: 1)
    }

    private var vHairline: some View {
        Rectangle().fill(theme.text.opacity(0.08)).frame(width: 1)
    }

    // MARK: - Shortcuts (keys without a visible control live here)

    private var shortcutButtons: some View {
        ZStack {
            // ⌘⌫ deletes the selected note only while the sidebar is open,
            // so it doesn't shadow delete-to-line-start in the editor.
            if showSidebar {
                Button("") { notePendingDelete = store.activeNote }
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
        Note(body: "Grocery list\nmilk, eggs, coffee", isPinned: true),
        Note(body: "Standup notes\nshipped the sidebar"),
        Note(body: "")
    ]))
    store.loadAll()
    store.activeNoteID = store.notes.first?.id
    return EditorView(store: store, showSidebar: true)
}
