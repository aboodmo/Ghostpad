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

    // Drives "breathing focus": .key when the panel is frontmost, dimmer otherwise.
    @Environment(\.controlActiveState) private var activeState
    private var isFocused: Bool { activeState == .key }

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
        // Breathing focus: content settles back when the panel isn't key and
        // sharpens when you click in.
        .opacity(isFocused ? 1.0 : 0.88)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(theme.text.opacity(isFocused ? 0.16 : 0.07), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.45), value: isFocused)
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

            FogDial(opacity: $opacity, tint: theme.text)

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
            .scrollIndicators(.never)
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
                    NoteRow(
                        note: note,
                        isActive: note.id == store.activeNoteID,
                        theme: theme,
                        snippet: snippet(of: note),
                        onTap: { store.setActive(id: note.id) },
                        onTogglePin: { store.setPinned(!note.isPinned, id: note.id) },
                        onDelete: { notePendingDelete = note }
                    )
                }
            }
            .padding(8)
        }
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

    /// Just the theme tint at the slider's opacity — genuinely see-through, so
    /// the person/screen behind the panel stays clearly visible. Text keeps its
    /// full strength (only the backing fades), so notes stay readable.
    private var panelBackground: some View {
        theme.background.opacity(opacity)
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

// MARK: - Sidebar row

/// A single note in the sidebar. The active note is marked by a thin accent
/// edge bar (reserved width, so selection never shifts the layout) and a soft
/// fill; hovering lifts the row a touch for tactile feedback.
private struct NoteRow: View {
    let note: Note
    let isActive: Bool
    let theme: Theme
    let snippet: String
    let onTap: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    private var fill: Color {
        if isActive { return theme.text.opacity(0.13) }
        if hovering { return theme.text.opacity(0.06) }
        return .clear
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(theme.accent)
                .frame(width: 2.5)
                .opacity(isActive ? 1 : 0)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .rotationEffect(.degrees(40))
                            .foregroundColor(theme.accent.opacity(0.85))
                    }
                    Text(note.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(snippet)
                    .font(.system(size: 11))
                    .foregroundColor(theme.text.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(fill)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .contextMenu {
            Button(note.isPinned ? "Unpin" : "Pin", action: onTogglePin)
            Button("Delete", role: .destructive, action: onDelete)
        }
        .foregroundColor(theme.text)
    }
}

/// Transparent AppKit backing that tells the window "a drag here is not a
/// window move." Placed under the fog dial so dragging it slides the value
/// instead of dragging the whole panel (which is movable by its background).
/// It doesn't override hit-testing or mouse handling, so SwiftUI's drag gesture
/// still receives the events via the responder chain.
private struct NonWindowDragging: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { _View() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class _View: NSView {
        override var mouseDownCanMoveWindow: Bool { false }
    }
}

// MARK: - Fog dial

/// The opacity control, reimagined as "clearing fog": a slim frosted track
/// whose fill recedes as opacity drops, with a soft knob and a monospaced %
/// that surfaces only while you interact. Drives the same $opacity binding the
/// rest of the app reads, so ⌘↑/⌘↓ and Settings stay in sync.
private struct FogDial: View {
    @Binding var opacity: Double
    var tint: Color

    @State private var dragging = false
    @State private var hovering = false

    private let range: ClosedRange<Double> = 0.1...1.0
    private let trackWidth: CGFloat = 86
    private let knob: CGFloat = 11

    private var fraction: CGFloat {
        CGFloat((opacity - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    private var revealed: Bool { dragging || hovering }

    var body: some View {
        HStack(spacing: 7) {
            Text("\(Int((opacity * 100).rounded()))%")
                .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundColor(tint.opacity(0.75))
                .lineLimit(1)
                .fixedSize()
                .opacity(revealed ? 1 : 0)
                .frame(width: 34, alignment: .trailing)

            track
        }
        .background(NonWindowDragging())
        .animation(.easeOut(duration: 0.18), value: revealed)
        .onHover { hovering = $0 }
        .help("Opacity (⌘↑ / ⌘↓)")
    }

    private var track: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = w * fraction
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
                Capsule(style: .continuous)
                    .fill(tint.opacity(revealed ? 0.55 : 0.4))
                    .frame(width: max(knob, x))
                Circle()
                    .fill(tint.opacity(0.95))
                    .frame(width: dragging ? knob + 2 : knob, height: dragging ? knob + 2 : knob)
                    .shadow(color: .black.opacity(0.35), radius: dragging ? 4 : 2, y: 1)
                    .offset(x: x - (dragging ? (knob + 2) : knob) / 2)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragging = true
                        let f = min(1, max(0, value.location.x / w))
                        opacity = range.lowerBound + Double(f) * (range.upperBound - range.lowerBound)
                    }
                    .onEnded { _ in dragging = false }
            )
        }
        .frame(width: trackWidth, height: 14)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dragging)
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
