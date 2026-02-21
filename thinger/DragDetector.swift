//
//  DragDetector.swift
//  thinger
//
//  Monitors global mouse events to detect when files are dragged near the notch region.
//  Triggers callbacks when drags enter/exit the notch area.
//

import Cocoa
import UniformTypeIdentifiers

// MARK: - DragDetector
/// Detects global drag operations and notifies when content enters the notch region.
final class DragDetector {
    
    // MARK: - Callback Types
    
    typealias VoidCallback = () -> Void
    typealias PositionCallback = (_ globalPoint: CGPoint) -> Void
    
    // MARK: - Callbacks
    
    /// Called when a drag enters the notch region
    var onDragEntersNotchRegion: VoidCallback?
    
    /// Called when a drag exits the notch region
    var onDragExitsNotchRegion: VoidCallback?
    
    /// Called on each drag move with the current mouse position
    var onDragMove: PositionCallback?
    
    // MARK: - Private Properties
    
    private var mouseDownMonitor: Any?
    private var mouseDraggedMonitor: Any?
    private var mouseUpMonitor: Any?
    
    /// Used to detect when content is added to the drag pasteboard
    private var pasteboardChangeCount: Int = -1
    
    /// Whether a mouse drag is currently in progress
    private var isDragging: Bool = false
    
    /// Whether the current drag contains valid content (files/URLs/text)
    private var isContentDragging: Bool = false
    
    /// Whether the drag is currently inside the notch region
    private var hasEnteredNotchRegion: Bool = false
    
    /// The rectangle defining the notch detection area
    private let notchRegion: CGRect
    
    /// Pasteboard used for drag operations
    private let dragPasteboard = NSPasteboard(name: .drag)
    
    // MARK: - Init
    
    /// Creates a new drag detector.
    /// - Parameter notchRegion: The screen rectangle where drags should be detected.
    init(notchRegion: CGRect) {
        self.notchRegion = notchRegion
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Validation
    
    /// Checks if the drag pasteboard contains valid content types.
    /// Valid types include: file URLs, web URLs, strings.
    private func hasValidDragContent() -> Bool {
        let validTypes: [NSPasteboard.PasteboardType] = [
            .fileURL,
            NSPasteboard.PasteboardType(UTType.url.identifier),
            .string
        ]
        return dragPasteboard.types?.contains(where: validTypes.contains) ?? false
    }
    
    // MARK: - Monitoring Control
    
    /// Starts monitoring global mouse events for drag detection.
    func startMonitoring() {
        stopMonitoring()
        
        // Monitor mouse down to reset state and capture pasteboard count
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            self.pasteboardChangeCount = self.dragPasteboard.changeCount
            self.isDragging = true
            self.isContentDragging = false
            self.hasEnteredNotchRegion = false
        }
        
        // Monitor drag movement and check for notch region intersection
        mouseDraggedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            guard let self = self else { return }
            guard self.isDragging else { return }
            
            // Detect if content was added to the drag pasteboard
            let newContent = self.dragPasteboard.changeCount != self.pasteboardChangeCount
            
            // Only count as content drag if valid content types are present
            if newContent && !self.isContentDragging && self.hasValidDragContent() {
                self.isContentDragging = true
            }
            
            // Only process position when actual content is being dragged
            if self.isContentDragging {
                let mouseLocation = NSEvent.mouseLocation
                self.onDragMove?(mouseLocation)
                
                // Track notch region entry/exit
                let containsMouse = self.notchRegion.contains(mouseLocation)
                if containsMouse && !self.hasEnteredNotchRegion {
                    self.hasEnteredNotchRegion = true
                    self.onDragEntersNotchRegion?()
                } else if !containsMouse && self.hasEnteredNotchRegion {
                    self.hasEnteredNotchRegion = false
                    self.onDragExitsNotchRegion?()
                }
            }
        }
        
        // Monitor mouse up to reset drag state
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            guard let self = self else { return }
            guard self.isDragging else { return }
            
            self.isDragging = false
            self.isContentDragging = false
            self.hasEnteredNotchRegion = false
            self.pasteboardChangeCount = -1
        }
    }
    
    /// Stops monitoring global mouse events.
    func stopMonitoring() {
        [mouseDownMonitor, mouseDraggedMonitor, mouseUpMonitor].forEach { monitor in
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        mouseDownMonitor = nil
        mouseDraggedMonitor = nil
        mouseUpMonitor = nil
        isDragging = false
        isContentDragging = false
        hasEnteredNotchRegion = false
    }
}
