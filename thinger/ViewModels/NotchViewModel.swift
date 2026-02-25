//
//  NotchViewModel.swift
//  thinger
//
//  The brain of the notch. Manages open/close state, drop targeting,
//  and multiple widget batches.
//

import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

// MARK: - NotchState

enum NotchState: Equatable {
    case closed
    case open
}

// MARK: - NotchTab

/// The tabs available in the expanded notch content area.
enum NotchTab: String, CaseIterable {
    case shelf
    case teleprompter
}

// MARK: - NotchViewModel

@MainActor
class NotchViewModel: ObservableObject {

    // MARK: - Tab State

    /// The currently active tab in the expanded notch.
    @Published var activeNotchTab: NotchTab = .shelf

    // MARK: - Teleprompter

    /// Shared teleprompter view model.
    let teleprompterVM = TeleprompterViewModel()

    // MARK: - Open Dimensions

    /// The open width, read directly from ``NotchConfiguration/minOpenWidth``.
    var openWidth: CGFloat {
        CGFloat(NotchConfiguration.shared.minOpenWidth)
    }

    /// The open height (currently fixed at configured minOpenHeight).
    var openHeight: CGFloat {
        CGFloat(NotchConfiguration.shared.minOpenHeight)
    }

    /// Convenience: the current open size.
    var openSize: CGSize {
        CGSize(width: openWidth, height: openHeight)
    }

    // MARK: - Widget Batches

    /// All active widget batches. Each DropZoneView binds to one.
    @Published var batches: [BatchViewModel] = []

    /// Creates a new empty batch and appends it.
    @discardableResult
    func addBatch() -> BatchViewModel {
        let batch = BatchViewModel(
            batch: FileBatch(title: "Batch \(batches.count + 1)", items: [], isPersisted: false)
        )
        batches.append(batch)
        return batch
    }

    /// Removes a specific batch by identity.
    func removeBatch(_ batch: BatchViewModel) {
        batches.removeAll { $0 === batch }
    }

    /// Removes all empty batches. Called when notch closes.
    func pruneEmptyBatches() {
        batches.removeAll { $0.isEmpty }
    }

    /// Clears everything.
    func clearAllBatches() {
        batches.forEach { $0.clear() }
        batches.removeAll()
    }

    /// True when there are no batches or all are empty.
    var hasNoFiles: Bool {
        batches.allSatisfy { $0.isEmpty }
    }

    // MARK: - Notch State

    @Published private(set) var notchState: NotchState = .closed
    @AppStorage("notchLocked") var isLocked: Bool = false

    /// Callback when notch state changes (used by AppDelegate for window resize)
    var onStateChange: ((NotchState) -> Void)?

    // MARK: - Drop Targeting

    @Published var globalDragTargeting: Bool = false
    @Published var activeTargetCount: Int = 0
    @Published var anyDropZoneTargeting: Bool = false
    @Published var dropEvent: Bool = false

    private var dragDebounceTask: Task<Void, Never>?

    func updateGlobalDragTargeting(_ targeted: Bool) {
        dragDebounceTask?.cancel()
        if targeted {
            globalDragTargeting = true
            // Auto-switch to shelf tab when files are dragged toward the notch
            if activeNotchTab != .shelf {
                activeNotchTab = .shelf
            }
        } else {
            dragDebounceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(NotchConfiguration.shared.dragDebounceDelay))
                guard !Task.isCancelled else { return }
                self?.globalDragTargeting = false
            }
        }
    }

    func reportTargetingChange(_ isTargeted: Bool) {
        if isTargeted {
            activeTargetCount += 1
//            anyDropZoneTargeting = true
        } else {
            activeTargetCount = max(0, activeTargetCount - 1)
//            if activeTargetCount == 0 {
//                anyDropZoneTargeting = false
//            }
        }
    }

    // MARK: - Sharing State (close prevention)

    @Published var preventNotchClose: Bool = false

    // MARK: - Hover State

    /// Whether the mouse is currently over the notch (physical or expanded)
    @Published var isHovering: Bool = false

    /// Task for delayed hover-off close
    private var hoverTask: Task<Void, Never>?

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        // Combine drop zone targeting from multiple sources
        Publishers.CombineLatest($globalDragTargeting, $activeTargetCount)
            .map { global, count in global || count > 0 }
            .assign(to: \.anyDropZoneTargeting, on: self)
            .store(in: &cancellables)
    }

    // MARK: - State Control

    func open() {
        guard notchState != .open else { return }
        guard !isLocked else { return }
        notchState = .open
        onStateChange?(.open)
    }

    func close() {
        guard notchState != .closed else { return }
        guard !isLocked else { return }
        if preventNotchClose { return }
        notchState = .closed
        onStateChange?(.closed)
        globalDragTargeting = false
        activeTargetCount = 0
        pruneEmptyBatches()
    }

    func toggle() {
        if notchState == .open { close() } else { open() }
    }

    // MARK: - Hover Control

    /// Call from any view that the mouse hovers over (physical notch, expanded content, etc.)
    func handleHover(_ hovering: Bool) {
        guard !isLocked else { return }

        isHovering = hovering

        if hovering {
            hoverTask?.cancel()
            open()
        } else if notchState != .closed && !anyDropZoneTargeting && !preventNotchClose {
            hoverTask?.cancel()
            hoverTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(NotchConfiguration.shared.hoverCloseDelay))
                guard !Task.isCancelled else { return }
                guard let self else { return }
                if !self.isHovering && !self.anyDropZoneTargeting {
                    self.close()
                }
            }
        }
    }

    // MARK: - Lock Control

    func lockNotch() { isLocked = true }
    func unlockNotch() { isLocked = false }
    func toggleLock() { isLocked.toggle() }

    // MARK: - AirDrop Sharing

    @MainActor
    func shareToAirDrop(items: [Any], from view: NSView? = nil) {
        let service = NSSharingService(named: .sendViaAirDrop) ?? NSSharingService.sharingServices(forItems: items).first(where: { $0.title == "AirDrop" })
        if let service = service, service.canPerform(withItems: items) {
            service.perform(withItems: items)
        } else {
            let picker = NSSharingServicePicker(items: items)
            if let view = view {
                picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
            }
        }
    }

    @MainActor
    func pickFilesForAirDrop(from view: NSView? = nil) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.title = "Select Files for AirDrop"
        
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            self.shareToAirDrop(items: panel.urls, from: view)
        }
    }

    func handleAirDropDrop(providers: [NSItemProvider], from view: NSView? = nil) async {
        var items: [Any] = []
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                if let result = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) {
                    if let data = result as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        items.append(url)
                    } else if let url = result as? URL {
                        items.append(url)
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let result = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) {
                    if let data = result as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        items.append(url)
                    } else if let url = result as? URL {
                        items.append(url)
                    }
                }
            }
        }
        
        if items.isEmpty {
            items = providers // Fallback to raw providers if url loading fails or it's text
        }
        
        await MainActor.run {
            self.shareToAirDrop(items: items, from: view)
        }
    }
}
