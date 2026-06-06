//
//  InMemoryNoteStorage.swift
//  Ghostpad
//
//  Non-persistent NoteStorage for SwiftUI previews (and future tests).
//

import Foundation
import NotesCore

final class InMemoryNoteStorage: NoteStorage {
    private var notes: [UUID: Note]

    init(seed: [Note] = []) {
        notes = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func loadAll() throws -> [Note] { Array(notes.values) }
    func save(_ note: Note) throws { notes[note.id] = note }
    func delete(id: UUID) throws { notes[id] = nil }
}
