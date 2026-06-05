//
//  NoteStorage.swift
//  NotesCore
//
//  Persistence abstraction. Concrete implementations live in the app layer.
//

import Foundation

public protocol NoteStorage {
    func loadAll() throws -> [Note]
    func save(_ note: Note) throws
    func delete(id: UUID) throws
}
