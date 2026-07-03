//
//  NoteTests.swift
//  NotesCoreTests
//
//  Title/preview/isEmpty semantics and backward-compatible decoding.
//

import XCTest
@testable import NotesCore

final class NoteTests: XCTestCase {

    // MARK: - Title

    func testTitleIsFirstLineTrimmed() {
        XCTAssertEqual(Note(body: "  Grocery list  \nmilk").title, "Grocery list")
    }

    func testTitleOfSingleLineBody() {
        XCTAssertEqual(Note(body: "Just a title").title, "Just a title")
    }

    func testBlankFirstLineIsUntitledEvenWithContentBelow() {
        // The sidebar must agree with the editor's title field, which edits
        // exactly the first line — so a blank first line means "Untitled".
        XCTAssertEqual(Note(body: "\nActual content").title, "Untitled")
    }

    func testEmptyBodyIsUntitled() {
        XCTAssertEqual(Note(body: "").title, "Untitled")
        XCTAssertEqual(Note(body: "   ").title, "Untitled")
    }

    // MARK: - Preview

    func testPreviewIsFirstNonEmptyLineAfterTitle() {
        XCTAssertEqual(Note(body: "Title\n\n  second line  \nthird").preview, "second line")
    }

    func testPreviewIsNilForTitleOnlyNote() {
        XCTAssertNil(Note(body: "Title").preview)
        XCTAssertNil(Note(body: "Title\n\n   ").preview)
    }

    func testPreviewExistsEvenWhenTitleLineIsBlank() {
        XCTAssertEqual(Note(body: "\nbody line").preview, "body line")
    }

    // MARK: - isEmpty

    func testIsEmptyIgnoresWhitespace() {
        XCTAssertTrue(Note(body: "").isEmpty)
        XCTAssertTrue(Note(body: " \n\t\n").isEmpty)
        XCTAssertFalse(Note(body: "x").isEmpty)
    }

    // MARK: - Decoding compatibility

    func testDecodingNoteWithoutIsPinnedDefaultsToFalse() throws {
        // A note encoded before pinning existed has no `isPinned` key.
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "body": "old note",
          "createdAt": 700000000,
          "modifiedAt": 700000000
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let note = try decoder.decode(Note.self, from: json)
        XCTAssertFalse(note.isPinned)
        XCTAssertEqual(note.body, "old note")
    }

    func testCodableRoundTrip() throws {
        let original = Note(body: "Round\ntrip", isPinned: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Note.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
