//
//  InMemoryNoteStorage.swift
//  NotesCore
//
//  Non-persistent NoteStorage for SwiftUI previews and tests.
//

import Foundation

public final class InMemoryNoteStorage: NoteStorage {
    private var notes: [UUID: Note]

    public init(seed: [Note] = []) {
        notes = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    public func loadAll() throws -> [Note] { Array(notes.values) }
    public func save(_ note: Note) throws { notes[note.id] = note }
    public func delete(id: UUID) throws { notes[id] = nil }
}
