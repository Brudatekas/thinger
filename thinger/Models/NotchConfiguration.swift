//
//  NotchConfiguration.swift
//  thinger
//
//  Centralized singleton for all tweakable notch parameters.
//  Every animation timing, dimension, and corner radius lives here so the
//  ControlPanelView can adjust them in real time.  Values persist via UserDefaults.
//

import SwiftUI
import Combine

/// Centralized configuration for all tweakable notch parameters.
///
/// ## Overview
///
/// `NotchConfiguration` is an `ObservableObject` singleton that owns every
/// animation, dimension, and timing constant used across the notch UI.
/// All views read from `NotchConfiguration.shared` instead of hardcoding values,
/// and the ``ControlPanelView`` binds directly to its `@Published` properties,
/// allowing real-time tweaking for screenshots, GIFs, and design iteration.
///
/// Values are persisted via `UserDefaults` using a `didSet` pattern on each
/// `@Published` property, so tweaks survive app relaunches.
///
/// ### Computed Helpers
///
/// - ``notchSpring`` — A SwiftUI `Animation` built from ``notchSpringResponse`` and ``notchSpringDamping``.
/// - ``widgetSpring`` — A SwiftUI `Animation` built from ``widgetSpringResponse`` and ``widgetSpringDamping``.
///
/// ## Topics
///
/// ### Animation
/// - ``notchSpringResponse``
/// - ``notchSpringDamping``
/// - ``widgetSpringResponse``
/// - ``widgetSpringDamping``
///
/// ### Dimensions
/// - ``minOpenWidth``
/// - ``minOpenHeight``
///
/// ### Corner Radii
/// - ``openTopCornerRadius``
/// - ``openBottomCornerRadius``
/// - ``closedTopCornerRadius``
/// - ``closedBottomCornerRadius``
///
/// ### Timing
/// - ``hoverCloseDelay``
/// - ``dragDebounceDelay``
///
/// ### Shadow
/// - ``shadowRadius``
/// - ``shadowOffsetY``
///
/// ### Teleprompter
/// - ``teleprompterSpeed``
/// - ``teleprompterFontSize``
/// - ``teleprompterMirror``
@MainActor
final class NotchConfiguration: ObservableObject {

    static let shared = NotchConfiguration()

    private let defaults = UserDefaults.standard

    // MARK: - Notch Animation

    /// Spring response for the main notch open/close animation.
    @Published var notchSpringResponse: Double {
        didSet { defaults.set(notchSpringResponse, forKey: "cfg.notchSpringResponse") }
    }

    /// Spring damping fraction for the main notch open/close animation.
    @Published var notchSpringDamping: Double {
        didSet { defaults.set(notchSpringDamping, forKey: "cfg.notchSpringDamping") }
    }

    /// A SwiftUI `Animation` built from the current notch spring values.
    var notchSpring: Animation {
        .spring(response: notchSpringResponse, dampingFraction: notchSpringDamping)
    }

    // MARK: - Widget Animation

    /// Spring response for widget card transitions (expand/collapse, add/remove).
    @Published var widgetSpringResponse: Double {
        didSet { defaults.set(widgetSpringResponse, forKey: "cfg.widgetSpringResponse") }
    }

    /// Spring damping fraction for widget card transitions.
    @Published var widgetSpringDamping: Double {
        didSet { defaults.set(widgetSpringDamping, forKey: "cfg.widgetSpringDamping") }
    }

    /// A SwiftUI `Animation` built from the current widget spring values.
    var widgetSpring: Animation {
        .spring(response: widgetSpringResponse, dampingFraction: widgetSpringDamping)
    }

    // MARK: - Corner Radii

    /// Top corner radius when the notch is **open** (outward "ear" curves).
    @Published var openTopCornerRadius: Double {
        didSet { defaults.set(openTopCornerRadius, forKey: "cfg.openTopCornerRadius") }
    }

    /// Bottom corner radius when the notch is **open** (inward rounding).
    @Published var openBottomCornerRadius: Double {
        didSet { defaults.set(openBottomCornerRadius, forKey: "cfg.openBottomCornerRadius") }
    }

    /// Top corner radius when the notch is **closed** (flat pill edge).
    @Published var closedTopCornerRadius: Double {
        didSet { defaults.set(closedTopCornerRadius, forKey: "cfg.closedTopCornerRadius") }
    }

    /// Bottom corner radius when the notch is **closed** (subtle pill rounding).
    @Published var closedBottomCornerRadius: Double {
        didSet { defaults.set(closedBottomCornerRadius, forKey: "cfg.closedBottomCornerRadius") }
    }

    // MARK: - Dimensions

    /// Minimum width of the notch when expanded. The notch may grow wider to fit widgets.
    @Published var minOpenWidth: Double {
        didSet { defaults.set(minOpenWidth, forKey: "cfg.minOpenWidth") }
    }

    /// Minimum height of the notch when expanded.
    @Published var minOpenHeight: Double {
        didSet { defaults.set(minOpenHeight, forKey: "cfg.minOpenHeight") }
    }

    // MARK: - Timing

    /// Delay (in milliseconds) before the notch closes after the mouse leaves.
    @Published var hoverCloseDelay: Int {
        didSet { defaults.set(hoverCloseDelay, forKey: "cfg.hoverCloseDelay") }
    }

    /// Delay (in milliseconds) for debouncing global drag targeting changes.
    @Published var dragDebounceDelay: Int {
        didSet { defaults.set(dragDebounceDelay, forKey: "cfg.dragDebounceDelay") }
    }

    // MARK: - Shadow

    /// Shadow blur radius when the notch is open.
    @Published var shadowRadius: Double {
        didSet { defaults.set(shadowRadius, forKey: "cfg.shadowRadius") }
    }

    /// Shadow vertical offset when the notch is open.
    @Published var shadowOffsetY: Double {
        didSet { defaults.set(shadowOffsetY, forKey: "cfg.shadowOffsetY") }
    }

    // MARK: - Debug

    /// Vertical offset for debugging notch positioning. Not persisted across resets.
    @Published var debugVerticalOffset: Double {
        didSet { defaults.set(debugVerticalOffset, forKey: "cfg.debugVerticalOffset") }
    }

    // MARK: - Teleprompter

    /// Teleprompter scroll speed in pixels per second.
    @Published var teleprompterSpeed: Double {
        didSet { defaults.set(teleprompterSpeed, forKey: "cfg.teleprompterSpeed") }
    }

    /// Teleprompter font size in points.
    @Published var teleprompterFontSize: Double {
        didSet { defaults.set(teleprompterFontSize, forKey: "cfg.teleprompterFontSize") }
    }

    /// Whether the teleprompter text is horizontally mirrored.
    @Published var teleprompterMirror: Bool {
        didSet { defaults.set(teleprompterMirror, forKey: "cfg.teleprompterMirror") }
    }

    // MARK: - Defaults

    /// All default values in one place for easy reset.
    enum Defaults {
        static let notchSpringResponse: Double = 0.35
        static let notchSpringDamping: Double = 1.0
        static let widgetSpringResponse: Double = 0.35
        static let widgetSpringDamping: Double = 0.8
        static let openTopCornerRadius: Double = 10
        static let openBottomCornerRadius: Double = 40
        static let closedTopCornerRadius: Double = 0
        static let closedBottomCornerRadius: Double = 10
        static let minOpenWidth: Double = 500
        static let minOpenHeight: Double = 180
        static let hoverCloseDelay: Int = 300
        static let dragDebounceDelay: Int = 50
        static let shadowRadius: Double = 20
        static let shadowOffsetY: Double = 10
        static let teleprompterSpeed: Double = 50
        static let teleprompterFontSize: Double = 28
        static let teleprompterMirror: Bool = false
    }

    // MARK: - Reset

    /// Resets all configuration values to their factory defaults.
    func resetToDefaults() {
        notchSpringResponse = Defaults.notchSpringResponse
        notchSpringDamping = Defaults.notchSpringDamping
        widgetSpringResponse = Defaults.widgetSpringResponse
        widgetSpringDamping = Defaults.widgetSpringDamping
        openTopCornerRadius = Defaults.openTopCornerRadius
        openBottomCornerRadius = Defaults.openBottomCornerRadius
        closedTopCornerRadius = Defaults.closedTopCornerRadius
        closedBottomCornerRadius = Defaults.closedBottomCornerRadius
        minOpenWidth = Defaults.minOpenWidth
        minOpenHeight = Defaults.minOpenHeight
        hoverCloseDelay = Defaults.hoverCloseDelay
        dragDebounceDelay = Defaults.dragDebounceDelay
        shadowRadius = Defaults.shadowRadius
        shadowOffsetY = Defaults.shadowOffsetY
        teleprompterSpeed = Defaults.teleprompterSpeed
        teleprompterFontSize = Defaults.teleprompterFontSize
        teleprompterMirror = Defaults.teleprompterMirror
    }

    // MARK: - Init

    private init() {
        // Load persisted values, falling back to defaults
        self.notchSpringResponse = defaults.object(forKey: "cfg.notchSpringResponse") as? Double ?? Defaults.notchSpringResponse
        self.notchSpringDamping = defaults.object(forKey: "cfg.notchSpringDamping") as? Double ?? Defaults.notchSpringDamping
        self.widgetSpringResponse = defaults.object(forKey: "cfg.widgetSpringResponse") as? Double ?? Defaults.widgetSpringResponse
        self.widgetSpringDamping = defaults.object(forKey: "cfg.widgetSpringDamping") as? Double ?? Defaults.widgetSpringDamping
        self.openTopCornerRadius = defaults.object(forKey: "cfg.openTopCornerRadius") as? Double ?? Defaults.openTopCornerRadius
        self.openBottomCornerRadius = defaults.object(forKey: "cfg.openBottomCornerRadius") as? Double ?? Defaults.openBottomCornerRadius
        self.closedTopCornerRadius = defaults.object(forKey: "cfg.closedTopCornerRadius") as? Double ?? Defaults.closedTopCornerRadius
        self.closedBottomCornerRadius = defaults.object(forKey: "cfg.closedBottomCornerRadius") as? Double ?? Defaults.closedBottomCornerRadius
        self.minOpenWidth = defaults.object(forKey: "cfg.minOpenWidth") as? Double ?? Defaults.minOpenWidth
        self.minOpenHeight = defaults.object(forKey: "cfg.minOpenHeight") as? Double ?? Defaults.minOpenHeight
        self.hoverCloseDelay = defaults.object(forKey: "cfg.hoverCloseDelay") as? Int ?? Defaults.hoverCloseDelay
        self.dragDebounceDelay = defaults.object(forKey: "cfg.dragDebounceDelay") as? Int ?? Defaults.dragDebounceDelay
        self.shadowRadius = defaults.object(forKey: "cfg.shadowRadius") as? Double ?? Defaults.shadowRadius
        self.shadowOffsetY = defaults.object(forKey: "cfg.shadowOffsetY") as? Double ?? Defaults.shadowOffsetY
        self.debugVerticalOffset = defaults.object(forKey: "cfg.debugVerticalOffset") as? Double ?? 0
        self.teleprompterSpeed = defaults.object(forKey: "cfg.teleprompterSpeed") as? Double ?? Defaults.teleprompterSpeed
        self.teleprompterFontSize = defaults.object(forKey: "cfg.teleprompterFontSize") as? Double ?? Defaults.teleprompterFontSize
        self.teleprompterMirror = defaults.object(forKey: "cfg.teleprompterMirror") as? Bool ?? Defaults.teleprompterMirror
    }
}
