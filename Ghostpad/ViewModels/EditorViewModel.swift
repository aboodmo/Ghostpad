//
//  EditorViewModel.swift
//  Ghostpad
//
//  Owns the note/document state and editing behavior. UI-framework-agnostic
//  except for ObservableObject. Disk persistence will land here later.
//

import Foundation
import Combine

final class EditorViewModel: ObservableObject {
    @Published var note: Note

    init(note: Note = Note(text: "Type here...")) {
        self.note = note
    }
}
