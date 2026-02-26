//
//  NotchWindow.swift
//  thinger
//
//  A custom NSPanel subclass dedicated to displaying the NotchView.
//

import AppKit
import SwiftUI

// MARK: - NotchWindow
/// A custom `NSPanel` subclass used for displaying the notch.
///
/// ## Overview
///
/// `NotchWindow` configures the panel to be a floating, transparent, borderless window
/// that behaves like a system overlay. It sits above the menu bar, ignores cycle matching,
/// and is constrained so it can seamlessly blend into the hardware notch space.
class NotchWindow: NSPanel {
    
    /// Creates a new `NotchWindow` instance.
    ///
    /// - Parameters:
    ///   - openSize: The fixed size for the window (typically its maximum expanded size).
    ///   - contentView: The complete SwiftUI view hierarchy to host within this panel.
    init<V: View>(openSize: CGSize, contentView: V) {
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: openSize.width, height: openSize.height),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        // Configure panel appearance
        self.isFloatingPanel = true
        self.isOpaque = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .clear
        self.isMovable = false
        self.level = .mainMenu + 3  // Above menu bar to overlay notch
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        self.hidesOnDeactivate = false
        self.isMovableByWindowBackground = false
        
        // Set SwiftUI content
        self.contentView = NSHostingView(rootView: contentView)
    }
}
