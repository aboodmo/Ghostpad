//
//  Note.swift
//  NotesCore
//
//  Platform-agnostic note model. Only Foundation — no AppKit/SwiftUI.
//

import Foundation

public struct Note: Identifiable, Codable, Equatable {
    public let id: UUID
    public var body: String
    public let createdAt: Date
    public var modifiedAt: Date

    public init(
        id: UUID = UUID(),
        body: String = "",
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    /// First non-empty, trimmed line of the body, or "Untitled".
    public var title: String {
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return "Untitled"
    }
}
