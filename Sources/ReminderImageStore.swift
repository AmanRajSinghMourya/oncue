//
//  ReminderImageStore.swift
//  OnCue
//
//  Stores the user's custom flyby image at
//  ~/Library/Application Support/OnCue/reminder-image.png
//  Resizes to ≤100×100 on save. Falls back to the bundled default asset.
//

import AppKit

final class ReminderImageStore {
    static let shared = ReminderImageStore()
    private init() {}

    private let fileName = "reminder-image.png"

    private var storageDirectory: URL {
        let dirs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appDir = dirs[0].appendingPathComponent("OnCue", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir
    }

    private var imageURL: URL {
        storageDirectory.appendingPathComponent(fileName)
    }

    private var defaultImageURL: URL? {
        Bundle.main.url(forResource: "ducky-flyby", withExtension: "png")
    }

    func currentImageURL() -> URL? {
        FileManager.default.fileExists(atPath: imageURL.path) ? imageURL : nil
    }

    func currentImage() -> NSImage? {
        guard let url = currentImageURL() else { return nil }
        return NSImage(contentsOf: url)
    }

    func displayImageURL() -> URL? {
        currentImageURL() ?? defaultImageURL
    }

    func displayImage() -> NSImage? {
        guard let url = displayImageURL() else { return nil }
        return NSImage(contentsOf: url)
    }

    @discardableResult
    func save(_ image: NSImage, maxDimension: CGFloat = 100) throws -> URL {
        let resized = resize(image, maxDimension: maxDimension)
        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ReminderImageStore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not convert image to PNG."
            ])
        }
        try png.write(to: imageURL)
        return imageURL
    }

    func clear() {
        try? FileManager.default.removeItem(at: imageURL)
    }

    private func resize(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return image }
        let scale = maxDimension / largest
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let out = NSImage(size: newSize)
        out.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .sourceOver,
            fraction: 1.0
        )
        out.unlockFocus()
        return out
    }
}
