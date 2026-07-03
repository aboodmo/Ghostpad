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
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        body: String = "",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isPinned = isPinned
    }

    // Backward-compatible decoding: notes saved before `isPinned` existed
    // simply default to false. (encode + CodingKeys stay synthesized.)
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        body = try c.decode(String.self, forKey: .body)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        modifiedAt = try c.decode(Date.self, forKey: .modifiedAt)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    /// The title is exactly the first line of the body, trimmed — the same
    /// line the editor's title field edits — or "Untitled" when it's blank.
    /// (It is deliberately NOT "first non-empty line": the sidebar and the
    /// title field must always agree on what the title is.)
    public var title: String {
        let first = body.prefix(while: { $0 != "\n" }).trimmingCharacters(in: .whitespaces)
        return first.isEmpty ? "Untitled" : first
    }

    /// First non-empty line after the title line — the sidebar's preview text.
    public var preview: String? {
        var isFirstLine = true
        for raw in body.split(separator: "\n", omittingEmptySubsequences: false) {
            if isFirstLine { isFirstLine = false; continue }
            let line = raw.trimmingCharacters(in: .whitespaces)
            if !line.isEmpty { return String(line) }
        }
        return nil
    }

    /// True when the note holds no content at all (whitespace doesn't count).
    public var isEmpty: Bool {
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
