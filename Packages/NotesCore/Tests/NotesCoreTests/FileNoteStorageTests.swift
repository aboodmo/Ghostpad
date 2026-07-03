//
//  FileNoteStorageTests.swift
//  NotesCoreTests
//
//  Round-trips through a temporary directory, plus the migration paths:
//  .md without a sidecar, and sidecars written before pinning existed.
//

import XCTest
@testable import NotesCore

final class FileNoteStorageTests: XCTestCase {

    private var directory: URL!
    private var storage: FileNoteStorage!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotesCoreTests-\(UUID().uuidString)", isDirectory: true)
        storage = FileNoteStorage(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSaveThenLoadRoundTrips() throws {
        let note = Note(body: "# Heading\n\nSome **markdown**.", isPinned: true)
        try storage.save(note)

        let loaded = try storage.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, note.id)
        XCTAssertEqual(loaded[0].body, note.body)
        XCTAssertEqual(loaded[0].isPinned, true)
        // Dates survive within JSON encoding precision.
        XCTAssertEqual(loaded[0].createdAt.timeIntervalSince1970,
                       note.createdAt.timeIntervalSince1970, accuracy: 0.01)
    }

    func testMarkdownFileIsPureMarkdown() throws {
        let note = Note(body: "just the text")
        try storage.save(note)
        let md = try String(contentsOf: directory.appendingPathComponent("\(note.id.uuidString).md"), encoding: .utf8)
        XCTAssertEqual(md, "just the text", "no frontmatter or metadata in the .md")
    }

    func testLoadsMarkdownWithoutSidecar() throws {
        // A user could drop a bare .md into the folder; it must still load.
        let id = UUID()
        try "orphan body".write(
            to: directory.appendingPathComponent("\(id.uuidString).md"),
            atomically: true, encoding: .utf8
        )
        let loaded = try storage.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].body, "orphan body")
        XCTAssertFalse(loaded[0].isPinned)
    }

    func testLoadsSidecarWithoutIsPinnedKey() throws {
        // Sidecars written before pinning existed lack the key entirely.
        let id = UUID()
        try "old note".write(
            to: directory.appendingPathComponent("\(id.uuidString).md"),
            atomically: true, encoding: .utf8
        )
        try #"{"createdAt": 700000000, "modifiedAt": 700000001}"#.write(
            to: directory.appendingPathComponent("\(id.uuidString).json"),
            atomically: true, encoding: .utf8
        )
        let loaded = try storage.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertFalse(loaded[0].isPinned)
        XCTAssertEqual(loaded[0].createdAt, Date(timeIntervalSinceReferenceDate: 700000000))
    }

    func testIgnoresNonUUIDAndNonMarkdownFiles() throws {
        try "not a note".write(
            to: directory.appendingPathComponent("README.md"),
            atomically: true, encoding: .utf8
        )
        try "junk".write(
            to: directory.appendingPathComponent("\(UUID().uuidString).txt"),
            atomically: true, encoding: .utf8
        )
        XCTAssertTrue(try storage.loadAll().isEmpty)
    }

    func testDeleteRemovesBothFiles() throws {
        let note = Note(body: "doomed")
        try storage.save(note)
        try storage.delete(id: note.id)

        let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testLoadAllSortsMostRecentlyModifiedFirst() throws {
        try storage.save(Note(body: "older", modifiedAt: Date(timeIntervalSince1970: 100)))
        try storage.save(Note(body: "newer", modifiedAt: Date(timeIntervalSince1970: 200)))
        XCTAssertEqual(try storage.loadAll().map(\.body), ["newer", "older"])
    }
}
