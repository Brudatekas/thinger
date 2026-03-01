//
//  thingerApp.swift
//  thinger
//
//  A macOS notch utility app with widget support, drag-drop AirDrop integration,
//  and teleprompter feature with global keyboard shortcuts.
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
                    // Reset debug offset when panel closes
//                    #if DEBUG
                    NotchConfiguration.shared.debugVerticalOffset = 0
//                    #endif
                    // Revert to accessory mode when control panel closes
                    NSApp.setActivationPolicy(.accessory)
                }
                .onAppear {
                    // Position control panel to the right of the notch
                    DispatchQueue.main.async {
                        if let cpWindow = NSApp.windows.first(where: { $0.title == "Control Panel" }),
                           let screen = NSScreen.main {
                            let notchDims = NotchDimensions.shared
                            let screenFrame = screen.frame
                            // Place the panel just right of the notch's right edge
                            let notchMaxX = screenFrame.midX + notchDims.notchWidth / 2 + 16
                            let panelY = screenFrame.maxY - cpWindow.frame.height - 40
                            cpWindow.setFrameOrigin(NSPoint(x: notchMaxX, y: panelY))
                        }
                    }
                }
        }
        .defaultSize(width: 420, height: 700)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        // Menu Bar Icon
        MenuBarExtra("Thinger", systemImage: "rectangle.topthird.inset.filled") {
            MenuBarMenuView(vm: appDelegate.viewModel)
        }
    }
}

struct MenuBarMenuView: View {
    @ObservedObject var vm: NotchViewModel
    
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            vm.toggle()
        } label: {
            Label("Toggle Notch", systemImage: "rectangle.topthird.inset.filled")
        }

        Button {
            vm.toggleLock()
        } label: {
            Label(vm.isLocked
                  ? "Unlock Notch"
                  : (vm.notchState == .open ? "Lock Open" : "Lock Closed"),
                  systemImage: vm.isLocked ? "lock.open" : "lock.fill")
        }

        Divider()

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit Thinger", systemImage: "power")
        }
        
        Divider()
        
        Button {
            openWindow(id: "control-panel")
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Label("Control Panel", systemImage: "slider.horizontal.3")
        }
    }
}

// MARK: - App Delegate
/// Manages the floating notch window and global drag detection.
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    /// The main notch window class `NotchWindow`
    var window: NotchWindow?
    
    /// View model for notch state
    var viewModel = NotchViewModel()
    
    /// Global drag detector for file drops
    var dragDetector: DragDetector?

    /// Monitors for teleprompter keyboard shortcuts
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    
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

        // Setup teleprompter keyboard shortcuts
        setupTeleprompterShortcuts()

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
        if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalKeyMonitor { NSEvent.removeMonitor(monitor) }
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Window Setup
    
    /// Creates and configures the floating notch panel.
    private func setupNotchWindow() {
        guard let screen = NSScreen.main else { return }
        
        let contentView = NotchView()
            .environmentObject(viewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        
        // Create the custom notch window with its exact style mask and behavior encapsulated
        // The window stays at this fixed size at all times.
        // SwiftUI handles all visual animation via matchedGeometryEffect internally.
        let panel = NotchWindow(openSize: viewModel.openSize, contentView: contentView)
        
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

        // Reposition window when debug vertical offset changes
//        #if DEBUG
        config.$debugVerticalOffset
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self, let window = self.window, let screen = NSScreen.main else { return }
                self.positionWindow(window, on: screen)
            }
            .store(in: &cancellables)
//        #endif
    }
    
    /// Positions the window at the top center of the screen.
    /// Uses the fixed openSize so the window never changes frame.
    private func positionWindow(_ window: NSWindow, on screen: NSScreen) {
        let screenFrame = screen.frame
        let size = viewModel.openSize
        
//        #if DEBUG
        let debugOffset = CGFloat(NotchConfiguration.shared.debugVerticalOffset)
//        #else
//        let debugOffset: CGFloat = 0
//        #endif
        
        // Use setFrameOrigin like Boring Notch does
        window.setFrameOrigin(NSPoint(
            x: screenFrame.origin.x + (screenFrame.width / 2) - size.width / 2,
            y: screenFrame.origin.y + screenFrame.height - size.height - debugOffset
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

    // MARK: - Teleprompter Shortcuts

    /// Registers local and global keyboard event monitors for teleprompter control.
    ///
    /// Shortcuts:
    /// - ⌘Space: Play / Pause
    /// - ⌘↑: Increase speed (+10 px/s)
    /// - ⌘↓: Decrease speed (−10 px/s)
    /// - ⌘→: Skip forward 3 lines
    /// - ⌘←: Rewind 3 lines
    /// - ⌘R: Reset to top
    private func setupTeleprompterShortcuts() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleTeleprompterKey(event) == true {
                return nil // consume the event
            }
            return event
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleTeleprompterKey(event)
        }
    }

    /// Handles a key event for teleprompter shortcuts.
    /// Returns `true` if the event was handled (consumed).
    @discardableResult
    private func handleTeleprompterKey(_ event: NSEvent) -> Bool {
        // Only respond to ⌘+key combos
        guard event.modifierFlags.contains(.command) else { return false }
        // Only respond if the teleprompter tab is currently active
        guard viewModel.activeNotchTab == .teleprompter else { return false }

        let tvm = viewModel.teleprompterVM
        let config = NotchConfiguration.shared

        switch event.keyCode {
        case 49: // Space
            tvm.togglePlayback()
            return true
        case 126: // Up arrow
            config.teleprompterSpeed = min(config.teleprompterSpeed + 10, 200)
            return true
        case 125: // Down arrow
            config.teleprompterSpeed = max(config.teleprompterSpeed - 10, 10)
            return true
        case 124: // Right arrow
            tvm.skipForward()
            return true
        case 123: // Left arrow
            tvm.rewind()
            return true
        case 15: // R
            tvm.reset()
            return true
        default:
            return false
        }
    }
}
