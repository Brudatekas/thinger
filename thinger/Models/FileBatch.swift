//
//  FileBatch.swift
//  thinger
//
//  A group of items (files, text, links) that you can drop things onto.
//  BatchViewModel also handles converting dropped NSItemProviders into ShelfItems.
//

import AppKit
import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - FileBatch

/// A container for a group of shelf items.
struct FileBatch: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var title: String = "Untitled Batch"
    var items: [ShelfItem] = []
    var isPersisted: Bool = false
}

// MARK: - BatchViewModel

/// Manages one FileBatch — handles drops, adding/removing items, and saving.
@MainActor
class BatchViewModel: ObservableObject, Identifiable {
    let id: UUID

    @Published var batch: FileBatch = FileBatch()
    @Published var isTargeted: Bool = false

    var items: [ShelfItem] { batch.items }
    var title: String { batch.title }
    var isEmpty: Bool { batch.items.isEmpty }

    /// Called when new items are added (e.g., to trigger sharing).
    var onItemsAdded: (([ShelfItem]) -> Void)?

    private let storageKeyPrefix = "com.thinger.batch."

    init(batch: FileBatch) {
        self.id = batch.id
        self.batch = batch
        if batch.isPersisted { loadFromStorage() }
    }

    init() {
        let newId = UUID()
        self.id = newId
        self.batch.id = newId
    }

    // MARK: - Drop Handling

    func handleDrop(providers: [NSItemProvider]) {
        Task {
            let newItems = await self.processProviders(providers)
            await MainActor.run { add(items: newItems) }
        }
    }

    // MARK: - Item Management

    func add(items newItems: [ShelfItem]) {
        let existingKeys = Set(batch.items.map { $0.identityKey })
        let unique = newItems.filter { !existingKeys.contains($0.identityKey) }

        print("Batch: adding \(unique.count) of \(newItems.count) items (\(newItems.count - unique.count) dupes)")
        guard !unique.isEmpty else { return }

        batch.items.append(contentsOf: unique)
        save()
        onItemsAdded?(unique)
    }

    func remove(_ item: ShelfItem) {
        batch.items.removeAll { $0.id == item.id }
        save()
    }

    func remove(at offsets: IndexSet) {
        batch.items.remove(atOffsets: offsets)
        save()
    }

    func clear() {
        batch.items.removeAll()
        save()
    }

    // MARK: - Persistence

    private var storageKey: String { storageKeyPrefix + batch.id.uuidString }

    private func save() {
        guard batch.isPersisted else { return }
        if let data = try? JSONEncoder().encode(batch.items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let loaded = try? JSONDecoder().decode([ShelfItem].self, from: data) {
            batch.items = loaded
            batch.items = batch.items.filter { item in
                if case .file = item.kind { return item.fileURL != nil }
                return true
            }
            save()
        }
    }

    // MARK: - Drop Processing (was ShelfDropService)

    /// Takes dropped items and returns ShelfItems we can use.
    func processProviders(_ providers: [NSItemProvider]) async -> [ShelfItem] {
        var results: [ShelfItem] = []
        for provider in providers {
            if let item = await processProvider(provider) {
                results.append(item)
            }
        }
        return results
    }

    /// Tries multiple ways to turn a dropped item into a ShelfItem.
    private func processProvider(_ provider: NSItemProvider) async -> ShelfItem? {
        print("Drop: types = \(provider.registeredTypeIdentifiers)")

        // 1) Try loading as URL directly
        if provider.canLoadObject(ofClass: URL.self),
           let url = await loadURLObject(from: provider) {
            print("Drop: got URL: \(url.absoluteString)")
            if url.isFileURL {
                if let bookmark = makeBookmark(for: url) {
                    return ShelfItem(kind: .file(bookmark: bookmark), isTemporary: false)
                }
            } else {
                return ShelfItem(kind: .link(url: url), isTemporary: false)
            }
        }

        // 2) Try explicit public.file-url
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let url = await loadItem(from: provider, type: UTType.fileURL.identifier) {
            print("Drop: got file URL fallback: \(url.path)")
            if let bookmark = makeBookmark(for: url) {
                return ShelfItem(kind: .file(bookmark: bookmark), isTemporary: false)
            }
        }

        // 3) Try every registered type
        for typeId in provider.registeredTypeIdentifiers {
            if typeId == UTType.fileURL.identifier || typeId == UTType.url.identifier { continue }
            print("Drop: trying type: \(typeId)")
            if let url = await loadItem(from: provider, type: typeId), url.isFileURL {
                if let bookmark = makeBookmark(for: url) {
                    return ShelfItem(kind: .file(bookmark: bookmark), isTemporary: false)
                }
            }
        }

        // 4) Maybe it's just text
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           let text = await loadText(from: provider) {
            print("Drop: got text: \(text.prefix(20))...")
            return ShelfItem(kind: .text(string: text), isTemporary: false)
        }

        print("Drop: couldn't process this item")
        return nil
    }

    // MARK: - Drop Helpers

    private func loadURLObject(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { cont in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                cont.resume(returning: url)
            }
        }
    }

    private func loadItem(from provider: NSItemProvider, type: String) async -> URL? {
        await withCheckedContinuation { cont in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                if let data = item as? Data {
                    cont.resume(returning: URL(dataRepresentation: data, relativeTo: nil))
                } else if let url = item as? URL {
                    cont.resume(returning: url)
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        if provider.canLoadObject(ofClass: String.self) {
            return await withCheckedContinuation { cont in
                _ = provider.loadObject(ofClass: String.self) { str, _ in
                    cont.resume(returning: str)
                }
            }
        }
        return await withCheckedContinuation { cont in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                if let s = item as? String {
                    cont.resume(returning: s)
                } else if let data = item as? Data, let s = String(data: data, encoding: .utf8) {
                    cont.resume(returning: s)
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }

    private func makeBookmark(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            print("Drop: bookmark failed for \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}
