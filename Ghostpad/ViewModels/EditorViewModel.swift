//
//  EditorViewModel.swift
//  Ghostpad
//
//  Owns the active note and persists edits to disk (debounced).
//

import Foundation
import Combine
import NotesCore

final class EditorViewModel: ObservableObject {
    @Published var note: Note

    private let storage: NoteStorage
    private var cancellables = Set<AnyCancellable>()

    init(storage: NoteStorage = FileNoteStorage()) {
        self.storage = storage

        // Load the most-recent note, or create+persist an empty one.
        if let first = (try? storage.loadAll())?.first {
            note = first
        } else {
            let fresh = Note(body: "")
            note = fresh
            try? storage.save(fresh)
        }

        // Debounce edits and write to disk 500ms after typing stops.
        $note
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] note in
                self?.persist(note)
            }
            .store(in: &cancellables)
    }

    private func persist(_ note: Note) {
        var updated = note
        updated.modifiedAt = Date()
        try? storage.save(updated)
    }
}
