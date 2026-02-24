//
//  thingerApp.swift
//  thinger
//
//  A macOS notch utility app with widget support and drag-drop AirDrop integration.
//  Based on Boring Notch patterns.
//

import SwiftUI
import Combine

// MARK: - App Entry Point
/// Main app struct. All user-facing controls live inside the notch's gear menu.
@main
struct ThingerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Control Panel Window
        Window("Control Panel", id: "control-panel") {
            ControlPanelView()
                .environmentObject(appDelegate.viewModel)
                .onDisappear {
                    // Revert to accessory mode when control panel closes
                    NSApp.setActivationPolicy(.accessory)
                }
        }
        .defaultSize(width: 420, height: 700)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

    }
}

// MARK: - App Delegate
/// Manages the floating notch window and global drag detection.
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    /// The main notch window
    var window: NSPanel?
    
    /// View model for notch state
    var viewModel = NotchViewModel()
    
    /// Global drag detector for file drops
    var dragDetector: DragDetector?
    
    // MARK: - Window Configuration
    
    /// Size of the notch window when open (fixed)
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Get the closed notch size based on actual screen notch dimensions.
    /// Delegates to NotchDimensions singleton.
    private func getClosedNotchSize(for screen: NSScreen) -> CGSize {
        NotchDimensions.shared.refresh(for: screen)
        return NotchDimensions.shared.closedSize
    }
    
    // MARK: - Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app to accessory (no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Create and configure the notch window
        setupNotchWindow()
        
        // Setup global drag detection
        setupDragDetector()
        
        // Listen for screen changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        dragDetector?.stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Window Setup
    
    /// Creates and configures the floating notch panel.
    private func setupNotchWindow() {
        guard let screen = NSScreen.main else { return }
        
        let contentView = NotchView()
            .environmentObject(viewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        
        // Create panel with Boring Notch's exact style mask
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]
        
        // Use the maximum (open) size for the window frame.
        // The window stays at this fixed size at all times.
        // SwiftUI handles all visual animation via matchedGeometryEffect internally.
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: viewModel.openSize.width, height: viewModel.openSize.height),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        // Configure panel appearance - matching BoringNotchSkyLightWindow
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .clear
        panel.isMovable = false
        panel.level = .mainMenu + 3  // Above menu bar to overlay notch
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.fullScreenAuxiliary, .stationary, .canJoinAllSpaces, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        
        // Set SwiftUI content
        panel.contentView = NSHostingView(rootView: contentView)
        
        // Position at top center using setFrameOrigin (like Boring Notch)
        positionWindow(panel, on: screen)
        
        panel.orderFrontRegardless()
        self.window = panel
        
        // State change callback — window no longer resizes;
        // all visual animation is handled by SwiftUI's matchedGeometryEffect.
        // We keep the callback for any future non-visual side effects.
        viewModel.onStateChange = { _ in
            // No window resize needed; SwiftUI handles it
        }

        // Resize & reposition window when config dimensions change
        let config = NotchConfiguration.shared
        config.$minOpenWidth
            .combineLatest(config.$minOpenHeight)
            .removeDuplicates(by: { $0 == $1 })
            .sink { [weak self] _, _ in
                guard let self, let window = self.window, let screen = NSScreen.main else { return }
                let newSize = self.viewModel.openSize
                window.setContentSize(newSize)
                self.positionWindow(window, on: screen)
            }
            .store(in: &cancellables)
    }
    
    /// Positions the window at the top center of the screen.
    /// Uses the fixed openSize so the window never changes frame.
    private func positionWindow(_ window: NSWindow, on screen: NSScreen) {
        let screenFrame = screen.frame
        let size = viewModel.openSize
        
        // Use setFrameOrigin like Boring Notch does
        window.setFrameOrigin(NSPoint(
            x: screenFrame.origin.x + (screenFrame.width / 2) - size.width / 2,
            y: screenFrame.origin.y + screenFrame.height - size.height
        ))
    }
    
    /// Handles notch state changes.
    /// With the fixed-frame approach, the window no longer resizes.
    /// SwiftUI's matchedGeometryEffect handles all visual transitions.
    private func handleNotchStateChange(_ state: NotchState) {
        // No-op: window stays at fixed max size.
        // SwiftUI handles visual animation internally.
    }
    
    // MARK: - Drag Detection
    
    /// Sets up the global drag detector for detecting file drags near the notch.
    private func setupDragDetector() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.frame
        let notchRect = CGRect(
            x: screenFrame.midX - viewModel.openSize.width / 2,
            y: screenFrame.maxY - 50,
            width: viewModel.openSize.width,
            height: 50
        )
        
        dragDetector = DragDetector(notchRegion: notchRect)
        
        dragDetector?.onDragEntersNotchRegion = { [weak self] in
            Task { @MainActor in
                self?.viewModel.updateGlobalDragTargeting(true)
                self?.viewModel.open()
            }
        }
        
        dragDetector?.onDragExitsNotchRegion = { [weak self] in
            Task { @MainActor in
                self?.viewModel.updateGlobalDragTargeting(false)
            }
        }
        
        dragDetector?.startMonitoring()
    }
    
    // MARK: - Screen Changes
    
    @objc private func screenConfigurationDidChange(_ notification: Notification) {
        guard let window = window, let screen = NSScreen.main else { return }
        positionWindow(window, on: screen)
        
        // Reconfigure drag detector for new screen layout
        setupDragDetector()
    }
}
