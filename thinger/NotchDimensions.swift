//
//  NotchDimensions.swift
//  thinger
//
//  Singleton that reads the physical notch dimensions from NSScreen APIs.
//  Provides the notch width, height, and position derived from:
//    - screen.auxiliaryTopLeftArea / auxiliaryTopRightArea (the "ears")
//    - screen.safeAreaInsets.top (the notch height)
//  Values are cached and refreshed when the screen changes.
//

import AppKit

// MARK: - NotchDimensions
/// Singleton providing the physical notch dimensions from the current screen.
/// Uses NSScreen's auxiliary areas and safe area insets (macOS 12+).
final class NotchDimensions {
    
    static let shared = NotchDimensions()
    
    // MARK: - Notch Properties
    
    /// Whether the current screen has a hardware notch
    private(set) var hasNotch: Bool = false
    
    /// Width of the physical notch (gap between left and right auxiliary areas)
    private(set) var notchWidth: CGFloat = 200
    
    /// Height of the notch (safe area inset from top)
    private(set) var notchHeight: CGFloat = 32
    
    /// X position of the notch on screen (left edge of the notch gap)
    private(set) var notchX: CGFloat = 0
    
    /// Full screen width (for reference/calculation)
    private(set) var screenWidth: CGFloat = 0
    
    /// Menu bar height (for non-notch screens)
    private(set) var menuBarHeight: CGFloat = 0
    
    // MARK: - Initialization
    
    private init() {
        refresh()
    }
    
    // MARK: - Refresh
    
    /// Re-reads notch dimensions from the current main screen.
    /// Call this when the screen configuration changes (e.g., display switch).
    func refresh(for screen: NSScreen? = nil) {
        let screen = screen ?? NSScreen.main
        guard let screen else { return }
        
        screenWidth = screen.frame.width
        menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        
        // Detect notch via auxiliary areas
        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {
            hasNotch = true
            
            // Notch width = gap between the two "ears"
            notchWidth = rightArea.origin.x - leftArea.maxX
            notchX = leftArea.maxX
            
            // Notch height from safe area
            notchHeight = screen.safeAreaInsets.top > 0
                ? screen.safeAreaInsets.top
                : menuBarHeight
        } else {
            // No notch — fall back to menu bar region
            hasNotch = false
            notchWidth = 200  // default pill width
            notchX = (screenWidth - notchWidth) / 2
            notchHeight = menuBarHeight > 0 ? menuBarHeight : 32
        }
    }
    
    // MARK: - Pixel Perfect Constants
    
    /// The physical top corner radius of the MacBook notch
    let hardwareTopCornerRadius: CGFloat = 6
    
    /// The physical bottom corner radius of the MacBook notch
    let hardwareBottomCornerRadius: CGFloat = 14
    
    // MARK: - Convenience
    
    /// The size of the usable notch area without the outward top corners
    var usableNotchSize: CGSize {
        CGSize(width: notchWidth - (hardwareTopCornerRadius * 2), height: notchHeight)
    }
    
    /// The closed notch size (used for initial display and hit-testing)
    var closedSize: CGSize {
        CGSize(width: notchWidth, height: notchHeight)
    }
}
