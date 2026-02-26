//
//  ThingerIntents.swift
//  thinger
//
//  Defines App Intents for controlling the app via Shortcuts and Spotlight.
//

import AppIntents
import AppKit

// MARK: - App Shortcuts Provider
struct ThingerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleNotchIntent(),
            phrases: [
                "Toggle \(.applicationName) Notch",
                "Toggle Notch in \(.applicationName)"
            ],
            shortTitle: "Toggle Notch",
            systemImageName: "rectangle.topthird.inset.filled"
        )
        AppShortcut(
            intent: OpenNotchIntent(),
            phrases: [
                "Open \(.applicationName) Notch",
                "Show \(.applicationName) Notch"
            ],
            shortTitle: "Open Notch",
            systemImageName: "arrow.down.to.line"
        )
        AppShortcut(
            intent: CloseNotchIntent(),
            phrases: [
                "Close \(.applicationName) Notch",
                "Hide \(.applicationName) Notch"
            ],
            shortTitle: "Close Notch",
            systemImageName: "arrow.up.to.line"
        )
        AppShortcut(
            intent: ToggleLockIntent(),
            phrases: [
                "Lock \(.applicationName) Notch",
                "Unlock \(.applicationName) Notch",
                "Toggle Notch Lock in \(.applicationName)"
            ],
            shortTitle: "Toggle Lock",
            systemImageName: "lock.fill"
        )
        AppShortcut(
            intent: ToggleMirrorIntent(),
            phrases: [
                "Toggle \(.applicationName) Mirror",
                "Toggle Webcam Mirror in \(.applicationName)"
            ],
            shortTitle: "Toggle Mirror",
            systemImageName: "web.camera.fill"
        )
        AppShortcut(
            intent: OpenMirrorIntent(),
            phrases: [
                "Open \(.applicationName) Mirror",
                "Show Webcam Mirror in \(.applicationName)"
            ],
            shortTitle: "Open Mirror",
            systemImageName: "web.camera"
        )
    }
}

// MARK: - Notch Intents

struct ToggleNotchIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Notch"
    static var description = IntentDescription("Toggles the Thinger notch open or closed.")

    @MainActor
    func perform() async throws -> some IntentResult {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.viewModel.toggle()
        }
        return .result()
    }
}

struct OpenNotchIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Notch"
    static var description = IntentDescription("Opens the Thinger notch.")

    @MainActor
    func perform() async throws -> some IntentResult {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.viewModel.open()
        }
        return .result()
    }
}

struct CloseNotchIntent: AppIntent {
    static var title: LocalizedStringResource = "Close Notch"
    static var description = IntentDescription("Closes the Thinger notch.")

    @MainActor
    func perform() async throws -> some IntentResult {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.viewModel.close()
        }
        return .result()
    }
}

struct ToggleLockIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Notch Lock"
    static var description = IntentDescription("Locks or unlocks the Thinger notch.")

    @MainActor
    func perform() async throws -> some IntentResult {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.viewModel.toggleLock()
        }
        return .result()
    }
}

// MARK: - Mirror Intents

struct ToggleMirrorIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Mirror"
    static var description = IntentDescription("Toggles the Thinger webcam mirror (Wirror).")

    @MainActor
    func perform() async throws -> some IntentResult {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            if appDelegate.viewModel.activeNotchTab != .wirror {
                appDelegate.viewModel.activeNotchTab = .wirror
            }
            appDelegate.viewModel.wirrorVM.isMirrored.toggle()
            if appDelegate.viewModel.wirrorVM.isMirrored {
                appDelegate.viewModel.open()
            }
        }
        return .result()
    }
}

struct OpenMirrorIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Mirror"
    static var description = IntentDescription("Opens the Thinger notch and shows the webcam mirror.")

    @MainActor
    func perform() async throws -> some IntentResult {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.viewModel.activeNotchTab = .wirror
            appDelegate.viewModel.open()
            if !appDelegate.viewModel.wirrorVM.isMirrored {
                appDelegate.viewModel.wirrorVM.isMirrored.toggle()
            }
        }
        return .result()
    }
}
