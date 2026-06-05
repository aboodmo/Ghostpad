//
//  Note.swift
//  Ghostpad
//
//  Platform-agnostic note model. Never import AppKit/SwiftUI here.
//

import Foundation

struct Note: Identifiable, Equatable {
    let id: UUID
    var text: String

    init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }
}
