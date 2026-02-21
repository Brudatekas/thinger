//
//  ShelfItem.swift
//  thinger
//
//  A single item on the shelf — could be a file, some text, or a link.
//

import AppKit
import Foundation

// MARK: - ShelfItemKind

/// What type of thing this shelf item holds.
enum ShelfItemKind: Codable, Equatable, Sendable {
    case file(bookmark: Data)
    case text(string: String)
    case link(url: URL)

    // Codable support
    enum CodingKeys: String, CodingKey { case type, value }
    enum KindTag: String, Codable { case file, text, link }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(KindTag.self, forKey: .type)
        switch type {
        case .file: self = .file(bookmark: try container.decode(Data.self, forKey: .value))
        case .text: self = .text(string: try container.decode(String.self, forKey: .value))
        case .link: self = .link(url: try container.decode(URL.self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .file(let bookmark):
            try container.encode(KindTag.file, forKey: .type)
            try container.encode(bookmark, forKey: .value)
        case .text(let string):
            try container.encode(KindTag.text, forKey: .type)
            try container.encode(string, forKey: .value)
        case .link(let url):
            try container.encode(KindTag.link, forKey: .type)
            try container.encode(url, forKey: .value)
        }
    }

    /// SF Symbol icon name for this type.
    var iconSymbolName: String {
        switch self {
        case .file: return "doc.fill"
        case .text: return "text.alignleft"
        case .link: return "link"
        }
    }
}

// MARK: - ShelfItem

@MainActor
struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var kind: ShelfItemKind
    var isTemporary: Bool

    init(id: UUID = UUID(), kind: ShelfItemKind, isTemporary: Bool = false) {
        self.id = id
        self.kind = kind
        self.isTemporary = isTemporary
    }

    /// A short name to show the user.
    var displayName: String {
        switch kind {
        case .file(let data):
            return resolveFileURL(from: data)?.lastPathComponent ?? "File"
        case .text(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.count > 30 ? String(trimmed.prefix(27)) + "..." : trimmed
        case .link(let url):
            let s = url.absoluteString
            if s.hasPrefix("https://") { return String(s.dropFirst(8)) }
            if s.hasPrefix("http://") { return String(s.dropFirst(7)) }
            return s
        }
    }

    /// The file URL (only for .file items).
    var fileURL: URL? {
        guard case .file(let bookmark) = kind else { return nil }
        return resolveFileURL(from: bookmark)
    }

    /// URL for this item (file or link). Nil for text.
    var itemURL: Foundation.URL? {
        switch kind {
        case .file(let bookmark): return resolveFileURL(from: bookmark)
        case .link(let url): return url
        case .text: return nil
        }
    }

    /// Icon to show for this item.
    var icon: NSImage {
        if let url = fileURL { return NSWorkspace.shared.icon(forFile: url.path) }
        return NSImage(systemSymbolName: kind.iconSymbolName, accessibilityDescription: nil) ?? NSImage()
    }

    /// Turns bookmark data back into a URL.
    private func resolveFileURL(from bookmarkData: Data) -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}

// MARK: - Identity Key (for deduplication)

extension ShelfItem {
    /// Unique key so we don't add the same item twice.
    var identityKey: String {
        switch kind {
        case .file(let bookmark):
            if let url = resolveFileURL(from: bookmark) {
                return "file://" + url.resolvingSymlinksInPath().path.lowercased()
            }
            return "file-bookmark://" + bookmark.base64EncodedString()
        case .link(let url):
            return "link://" + url.absoluteString
        case .text(let s):
            return "text://" + s
        }
    }
}
