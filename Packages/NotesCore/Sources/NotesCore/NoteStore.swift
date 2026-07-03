//
//  NoteStore.swift
//  NotesCore
//
//  Observable multi-note store. Owns the in-memory note list + active selection
//  and persists changes through an injected NoteStorage (debounced on edit).
//

import Foundation
import Combine

@MainActor
public final class NoteStore: ObservableObject {
    @Published public private(set) var notes: [Note] = []
    @Published public var activeNoteID: UUID?

    private let storage: NoteStorage
    private let saveSubject = PassthroughSubject<UUID, Never>()
    private var cancellables = Set<AnyCancellable>()

    /// Edits whose disk write is still waiting on the debounce. `flush()`
    /// drains this so quitting/hiding never loses the last keystrokes.
    private var pendingSaveIDs = Set<UUID>()

    public init(storage: NoteStorage) {
        self.storage = storage

        // Debounce disk writes 500ms after the last edit to a note.
        saveSubject
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] id in
                MainActor.assumeIsolated { self?.persist(id) }
            }
            .store(in: &cancellables)
    }

    /// The note currently selected for editing, if any.
    public var activeNote: Note? {
        guard let id = activeNoteID else { return nil }
        return notes.first { $0.id == id }
    }

    /// Load all notes from storage (most recently modified first).
    public func loadAll() {
        notes = ((try? storage.loadAll()) ?? []).sorted { $0.modifiedAt > $1.modifiedAt }
    }

    /// Make an empty note active and return it. Reuses an existing empty note
    /// if there is one, so mashing "New Note" never breeds Untitled duplicates.
    @discardableResult
    public func create() -> Note {
        if let existing = notes.first(where: { $0.isEmpty }) {
            activeNoteID = existing.id
            return existing
        }
        let note = Note(body: "")
        try? storage.save(note)
        notes.insert(note, at: 0)
        activeNoteID = note.id
        return note
    }

    /// Delete a note; if it was active, fall back to the first remaining note.
    public func delete(id: UUID) {
        pendingSaveIDs.remove(id)
        try? storage.delete(id: id)
        notes.removeAll { $0.id == id }
        if activeNoteID == id {
            activeNoteID = notes.first?.id
        }
    }

    public func setActive(id: UUID) {
        activeNoteID = id
    }

    /// Pin/unpin a note and persist immediately (a discrete action, not debounced).
    public func setPinned(_ isPinned: Bool, id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].isPinned = isPinned
        persist(id)
    }

    /// Apply an edit in memory immediately, then debounce the disk write.
    public func update(id: UUID, body: String) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].body = body
        notes[idx].modifiedAt = Date()
        pendingSaveIDs.insert(id)
        saveSubject.send(id)
    }

    /// Write every edit still waiting on the debounce, right now. Called when
    /// the app terminates or the panel hides — a note-taking app must never
    /// lose the sentence typed in the last half-second.
    public func flush() {
        for id in pendingSaveIDs { persist(id) }
    }

    private func persist(_ id: UUID) {
        pendingSaveIDs.remove(id)
        guard let note = notes.first(where: { $0.id == id }) else { return }
        try? storage.save(note)
    }
}
