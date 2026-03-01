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
enum NotchTab: String, CaseIterable, Hashable {
    case shelf
    case teleprompter
    case wirror
}

// MARK: - NotchViewModel

@MainActor
class NotchViewModel: ObservableObject {

    // MARK: - Tab State
    
    init() {
        if let tabRaw = UserDefaults.standard.string(forKey: "notch.activeTab"),
           let tab = NotchTab(rawValue: tabRaw) {
            self.activeNotchTab = tab
        } else {
            self.activeNotchTab = .shelf
        }

        // Combine drop zone targeting from multiple sources
        Publishers.CombineLatest($globalDragTargeting, $activeTargetCount)
            .map { global, count in global || count > 0 }
            .assign(to: \.anyDropZoneTargeting, on: self)
            .store(in: &cancellables)
        

    }

    /// The currently active tab in the expanded notch.
    @Published var activeNotchTab: NotchTab {
        didSet {
            print(self.activeNotchTab)
        }
    }

    // MARK: - Teleprompter

    /// Shared teleprompter view model.
    let teleprompterVM = TeleprompterViewModel()

    /// Shared wirror (webcam mirror) view model.
    let wirrorVM = WirrorViewModel()

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
    @Published var isLocked: Bool = false
    
    /// Toggles whether the notch pushes down to reveal the underlying menu bar
    /// with a translucent interactive cutout mask.
    @Published var isMenuBarRevealed: Bool = false
    
    /// The global screen coordinates of the mouse, used to move the translucent cut-out.
    @Published var globalMouseLocation: CGPoint = .zero

    @Published var mouseMonitor: Any?
    @Published var localMouseMonitor: Any?

    /// Callback when notch state changes (used by AppDelegate for window resize)
    var onStateChange: ((NotchState) -> Void)?

    // MARK: - Drop Targeting

    @Published var globalDragTargeting: Bool = false
    @Published var activeTargetCount: Int = 0
    @Published var anyDropZoneTargeting: Bool = false
    @Published var dropEvent: Bool = false
    
    /// Dynamically populated array of sharing services that accept the currently dragged items.
    @Published var activeShareServices: [NSSharingService] = []

    private var dragDebounceTask: Task<Void, Never>?
    private var shareServiceDiscoveryTask: Task<Void, Never>?
    
    func toggleMenuBarRevealed() {
        isMenuBarRevealed.toggle()
        
        if isMenuBarRevealed {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        // 1. Global Monitor (Events outside your app)
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.globalMouseLocation = NSEvent.mouseLocation
        }
        
        // 2. Local Monitor (Events inside your app)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.globalMouseLocation = NSEvent.mouseLocation
            return event
        }
    }

    private func stopMonitoring() {
        // Use a small helper or iterate to ensure cleanup
        [mouseMonitor, localMouseMonitor].compactMap { $0 }.forEach { NSEvent.removeMonitor($0) }
        
        // Crucial: Clear the references so they don't hold 'dead' monitors
        mouseMonitor = nil
        localMouseMonitor = nil
    }
    func updateGlobalDragTargeting(_ targeted: Bool) {
        dragDebounceTask?.cancel()
        shareServiceDiscoveryTask?.cancel()
        
        if targeted {
            globalDragTargeting = true
            // Auto-switch to shelf tab when files are dragged toward the notch
            if activeNotchTab != .shelf {
                activeNotchTab = .shelf
            }
            
            // Discover sharing services for dragged items
            shareServiceDiscoveryTask = Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Briefly yield so we don't block the initial drag target animation
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                
                let pasteboard = NSPasteboard(name: .drag)
                var draggedURLs: [URL]? = nil
                
                // Try reading URLs directly
                if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
                    draggedURLs = urls
                } else if let types = pasteboard.types, types.contains(.fileURL) {
                    // Fallback to checking file types manually if needed
                    draggedURLs = pasteboard.pasteboardItems?.compactMap { item -> URL? in
                        guard let string = item.string(forType: .fileURL) else { return nil }
                        return URL(string: string)
                    }
                }
                
                if let urls = draggedURLs, !urls.isEmpty {
                    // Get all sharing services for these items
                    let services = NSSharingService.sharingServices(forItems: urls)
                    
                    let disabledSet = Set(NotchConfiguration.shared.disabledShareServices)
                    let filteredServices = services.filter { !disabledSet.contains($0.title) }
                    
                    self.activeShareServices = filteredServices
                } else {
                    self.activeShareServices = []
                }
            }
        } else {
            dragDebounceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(NotchConfiguration.shared.dragDebounceDelay))
                guard !Task.isCancelled else { return }
                guard let self = self else { return }
                self.globalDragTargeting = false
                if !self.anyDropZoneTargeting {
                    self.activeShareServices = []
                }
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
        } else if notchState != .closed && activeTargetCount == 0 && !preventNotchClose {
            hoverTask?.cancel()
            hoverTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(NotchConfiguration.shared.hoverCloseDelay))
                guard !Task.isCancelled else { return }
                guard let self else { return }
                if !self.isHovering && self.activeTargetCount == 0 {
                    self.close()
                }
            }
        }
    }

    // MARK: - Lock Control

    func lockNotch() { isLocked = true }
    func unlockNotch() { isLocked = false }
    func toggleLock() { isLocked.toggle() }

    // MARK: - Sharing Logic
    
    /// Shares the given items using the specified service.
    @MainActor
    func shareItems(items: [Any], service: NSSharingService, from view: NSView? = nil) {
        if service.canPerform(withItems: items) {
            service.perform(withItems: items)
        } else {
            // Fallback sheet
            let picker = NSSharingServicePicker(items: items)
            if let view = view {
                picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
            }
        }
    }

    @MainActor
    func shareToAirDrop(items: [Any], from view: NSView? = nil) {
        let service = NSSharingService(named: .sendViaAirDrop) ?? NSSharingService.sharingServices(forItems: items).first(where: { $0.title == "AirDrop" })
        if let service = service {
            shareItems(items: items, service: service, from: view)
        } else {
            // Fallback sheet
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

    func handleServiceDrop(providers: [NSItemProvider], service: NSSharingService, from view: NSView? = nil) async {
        let items = await extractItems(from: providers)
        await MainActor.run {
            self.shareItems(items: items, service: service, from: view)
        }
    }

    func handleAirDropDrop(providers: [NSItemProvider], from view: NSView? = nil) async {
        let items = await extractItems(from: providers)
        await MainActor.run {
            self.shareToAirDrop(items: items, from: view)
        }
    }
    
    /// Extracts actionable items (URLs or raw providers) from dropping providers.
    private func extractItems(from providers: [NSItemProvider]) async -> [Any] {
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
        
        return items
    }
}
