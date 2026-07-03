//
//  NoteStoreTests.swift
//  NotesCoreTests
//
//  Store semantics: creation/reuse, deletion fallback, debounced persistence,
//  and flush() — the guarantee that quitting never loses the last edit.
//

import XCTest
@testable import NotesCore

/// Records every storage call so tests can assert exactly when writes happen.
private final class SpyStorage: NoteStorage {
    var seed: [Note] = []
    private(set) var saved: [Note] = []
    private(set) var deleted: [UUID] = []

    func loadAll() throws -> [Note] { seed }
    func save(_ note: Note) throws { saved.append(note) }
    func delete(id: UUID) throws { deleted.append(id) }
}

@MainActor
final class NoteStoreTests: XCTestCase {

    private var storage: SpyStorage!
    private var store: NoteStore!

    override func setUp() {
        super.setUp()
        storage = SpyStorage()
        store = NoteStore(storage: storage)
    }

    // MARK: - Create

    func testCreatePersistsAndActivates() {
        let note = store.create()
        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(store.activeNoteID, note.id)
        XCTAssertEqual(storage.saved.map(\.id), [note.id])
    }

    func testCreateReusesExistingEmptyNote() {
        let first = store.create()
        let second = store.create()
        // No duplicate: the empty note is reused, no extra disk write.
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(storage.saved.count, 1)
    }

    func testCreateMakesNewNoteWhenExistingOnesHaveContent() {
        let first = store.create()
        store.update(id: first.id, body: "content")
        let second = store.create()
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(store.notes.count, 2)
    }

    // MARK: - Delete

    func testDeleteActiveFallsBackToFirstRemaining() {
        let a = store.create()
        store.update(id: a.id, body: "a")
        let b = store.create()
        store.update(id: b.id, body: "b")
        store.setActive(id: b.id)

        store.delete(id: b.id)
        XCTAssertEqual(storage.deleted, [b.id])
        XCTAssertEqual(store.activeNoteID, store.notes.first?.id)
    }

    func testDeleteLastNoteClearsActive() {
        let note = store.create()
        store.delete(id: note.id)
        XCTAssertNil(store.activeNoteID)
        XCTAssertTrue(store.notes.isEmpty)
    }

    // MARK: - Update / debounce / flush

    func testUpdateMutatesMemoryImmediatelyButDebouncesDisk() {
        let note = store.create()
        let savesAfterCreate = storage.saved.count

        store.update(id: note.id, body: "typed text")
        XCTAssertEqual(store.activeNote?.body, "typed text")
        // Disk write is debounced — nothing saved yet.
        XCTAssertEqual(storage.saved.count, savesAfterCreate)
    }

    func testFlushWritesPendingEditImmediately() {
        let note = store.create()
        store.update(id: note.id, body: "last-second sentence")

        store.flush()
        XCTAssertEqual(storage.saved.last?.body, "last-second sentence")
    }

    func testFlushIsIdempotent() {
        let note = store.create()
        store.update(id: note.id, body: "once")
        store.flush()
        let count = storage.saved.count
        store.flush()
        XCTAssertEqual(storage.saved.count, count, "second flush had nothing pending")
    }

    func testDebouncedSaveEventuallyFires() {
        let note = store.create()
        store.update(id: note.id, body: "debounced")

        let exp = expectation(description: "debounce elapsed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { exp.fulfill() }
        wait(for: [exp], timeout: 2)

        XCTAssertEqual(storage.saved.last?.body, "debounced")
    }

    func testDeleteCancelsPendingSave() {
        let note = store.create()
        store.update(id: note.id, body: "will be deleted")
        store.delete(id: note.id)

        store.flush()
        XCTAssertFalse(storage.saved.contains { $0.body == "will be deleted" })
    }

    // MARK: - Pinning

    func testSetPinnedPersistsImmediately() {
        let note = store.create()
        let savesAfterCreate = storage.saved.count
        store.setPinned(true, id: note.id)
        XCTAssertEqual(storage.saved.count, savesAfterCreate + 1)
        XCTAssertEqual(storage.saved.last?.isPinned, true)
    }

    // MARK: - Loading

    func testLoadAllSortsMostRecentlyModifiedFirst() {
        let old = Note(body: "old", modifiedAt: Date(timeIntervalSince1970: 100))
        let new = Note(body: "new", modifiedAt: Date(timeIntervalSince1970: 200))
        storage.seed = [old, new]

        store.loadAll()
        XCTAssertEqual(store.notes.map(\.body), ["new", "old"])
    }
}
