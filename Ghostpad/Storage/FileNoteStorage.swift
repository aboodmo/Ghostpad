//
//  FileNoteStorage.swift
//  Ghostpad
//
//  Disk-backed NoteStorage: one markdown file per note in Application Support,
//  with a small JSON sidecar holding timestamps (keeps the .md pure markdown).
//

import Foundation
import NotesCore

struct FileNoteStorage: NoteStorage {
    private let directory: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = appSupport
            .appendingPathComponent("Ghostpad", isDirectory: true)
            .appendingPathComponent("notes", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func loadAll() throws -> [Note] {
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let notes: [Note] = urls
            .filter { $0.pathExtension == "md" }
            .compactMap { url in
                guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { return nil }
                let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let meta = metadata(for: id)
                return Note(
                    id: id,
                    body: body,
                    createdAt: meta?.createdAt ?? Date(),
                    modifiedAt: meta?.modifiedAt ?? Date()
                )
            }
        return notes.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func save(_ note: Note) throws {
        try note.body.write(to: bodyURL(note.id), atomically: true, encoding: .utf8)
        let data = try JSONEncoder().encode(Metadata(createdAt: note.createdAt, modifiedAt: note.modifiedAt))
        try data.write(to: metaURL(note.id), options: .atomic)
    }

    func delete(id: UUID) throws {
        try? fileManager.removeItem(at: bodyURL(id))
        try? fileManager.removeItem(at: metaURL(id))
    }

    // MARK: - Helpers

    private struct Metadata: Codable {
        let createdAt: Date
        let modifiedAt: Date
    }

    private func bodyURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).md") }
    private func metaURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).json") }

    private func metadata(for id: UUID) -> Metadata? {
        guard let data = try? Data(contentsOf: metaURL(id)) else { return nil }
        return try? JSONDecoder().decode(Metadata.self, from: data)
    }
}
