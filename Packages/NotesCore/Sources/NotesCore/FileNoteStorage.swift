//
//  FileNoteStorage.swift
//  NotesCore
//
//  Disk-backed NoteStorage: one markdown file per note, with a small JSON
//  sidecar holding timestamps + pin state (keeps the .md pure markdown).
//  Pure Foundation, so it lives with the model and is tested directly.
//

import Foundation

public struct FileNoteStorage: NoteStorage {
    private let directory: URL
    private let fileManager: FileManager

    /// Production location: Application Support/Ghostpad/notes (inside the
    /// sandbox container when the app is sandboxed).
    public init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.init(
            directory: appSupport
                .appendingPathComponent("Ghostpad", isDirectory: true)
                .appendingPathComponent("notes", isDirectory: true),
            fileManager: fileManager
        )
    }

    /// Injectable root — tests point this at a temporary directory.
    public init(directory: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directory = directory
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func loadAll() throws -> [Note] {
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
                    modifiedAt: meta?.modifiedAt ?? Date(),
                    isPinned: meta?.isPinned ?? false
                )
            }
        return notes.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    public func save(_ note: Note) throws {
        try note.body.write(to: bodyURL(note.id), atomically: true, encoding: .utf8)
        let data = try JSONEncoder().encode(Metadata(createdAt: note.createdAt, modifiedAt: note.modifiedAt, isPinned: note.isPinned))
        try data.write(to: metaURL(note.id), options: .atomic)
    }

    public func delete(id: UUID) throws {
        try? fileManager.removeItem(at: bodyURL(id))
        try? fileManager.removeItem(at: metaURL(id))
    }

    // MARK: - Helpers

    private struct Metadata: Codable {
        let createdAt: Date
        let modifiedAt: Date
        let isPinned: Bool

        init(createdAt: Date, modifiedAt: Date, isPinned: Bool) {
            self.createdAt = createdAt
            self.modifiedAt = modifiedAt
            self.isPinned = isPinned
        }

        // Sidecars written before pinning existed have no `isPinned` key.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            createdAt = try c.decode(Date.self, forKey: .createdAt)
            modifiedAt = try c.decode(Date.self, forKey: .modifiedAt)
            isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        }
    }

    private func bodyURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).md") }
    private func metaURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).json") }

    private func metadata(for id: UUID) -> Metadata? {
        guard let data = try? Data(contentsOf: metaURL(id)) else { return nil }
        return try? JSONDecoder().decode(Metadata.self, from: data)
    }
}
