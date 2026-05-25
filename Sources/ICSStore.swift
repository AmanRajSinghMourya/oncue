//
//  ICSStore.swift
//  OnCue
//
//  Manages user-imported .ics files in ~/Library/Application Support/OnCue/Calendars/
//

import Foundation

final class ICSStore {
    static let shared = ICSStore()

    private let fm = FileManager.default

    private var directory: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("OnCue/Calendars", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func listFiles() -> [URL] {
        (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension.lowercased() == "ics" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
    }

    /// Copies the .ics at `source` into our managed directory.
    /// Replaces any file with the same name (so re-exporting overwrites).
    @discardableResult
    func importFile(from source: URL) throws -> URL {
        let needsSecurity = source.startAccessingSecurityScopedResource()
        defer { if needsSecurity { source.stopAccessingSecurityScopedResource() } }

        let dest = directory.appendingPathComponent(source.lastPathComponent)
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.copyItem(at: source, to: dest)
        return dest
    }

    func delete(_ url: URL) throws {
        try fm.removeItem(at: url)
    }

    func displayName(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }
}
