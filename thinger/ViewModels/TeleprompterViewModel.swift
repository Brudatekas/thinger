//
//  TeleprompterViewModel.swift
//  thinger
//
//  ViewModel owning all teleprompter state: script text, scroll position,
//  playback control, speed, and font size. Uses a Timer to smoothly
//  increment the scroll offset when playing.
//

import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers

// MARK: - TeleprompterViewModel

/// The brain of the teleprompter feature.
///
/// ## Overview
///
/// `TeleprompterViewModel` manages the script text, scroll offset, playback state,
/// and speed for the notch teleprompter. A 60fps `Timer` drives smooth scrolling
/// when playback is active.
///
/// ## Topics
///
/// ### Playback
/// - ``play()``
/// - ``pause()``
/// - ``togglePlayback()``
///
/// ### Navigation
/// - ``skipForward(lines:)``
/// - ``rewind(lines:)``
/// - ``reset()``
///
/// ### Loading
/// - ``loadFromClipboard()``
/// - ``loadFromFile()``
@MainActor
class TeleprompterViewModel: ObservableObject {

    // MARK: - Published State

    /// The full teleprompter script text. Persisted via UserDefaults.
    @Published var scriptText: String {
        didSet { UserDefaults.standard.set(scriptText, forKey: "teleprompter.scriptText") }
    }

    /// Current vertical scroll offset in points. Drives the text position.
    @Published var scrollOffset: CGFloat = 0

    /// Whether auto-scrolling is active.
    @Published var isPlaying: Bool = false

    /// The total height of the rendered text content (set by the view).
    @Published var contentHeight: CGFloat = 0

    /// The visible viewport height (set by the view).
    @Published var viewportHeight: CGFloat = 0

    // MARK: - Computed

    /// Scroll speed in pixels per second, read from NotchConfiguration.
    var speed: Double {
        get { NotchConfiguration.shared.teleprompterSpeed }
        set { NotchConfiguration.shared.teleprompterSpeed = newValue }
    }

    /// Display font size, read from NotchConfiguration.
    var fontSize: Double {
        get { NotchConfiguration.shared.teleprompterFontSize }
        set { NotchConfiguration.shared.teleprompterFontSize = newValue }
    }

    /// Whether the text is horizontally mirrored (for real teleprompter glass).
    var isMirrored: Bool {
        get { NotchConfiguration.shared.teleprompterMirror }
        set { NotchConfiguration.shared.teleprompterMirror = newValue }
    }

    /// Whether the script is empty.
    var isEmpty: Bool { scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Progress through the script (0.0–1.0).
    var progress: Double {
        guard contentHeight > viewportHeight else { return 0 }
        let maxOffset = contentHeight - viewportHeight
        return min(1.0, max(0.0, Double(scrollOffset) / Double(maxOffset)))
    }

    // MARK: - Timer

    /// The display timer driving smooth scroll increments.
    private var scrollTimer: Timer?

    // MARK: - Init

    init() {
        self.scriptText = UserDefaults.standard.string(forKey: "teleprompter.scriptText") ?? ""
    }

    deinit {
        scrollTimer?.invalidate()
    }

    // MARK: - Playback Control

    /// Start auto-scrolling the teleprompter.
    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        startTimer()
    }

    /// Pause auto-scrolling.
    func pause() {
        guard isPlaying else { return }
        isPlaying = false
        stopTimer()
    }

    /// Toggle between play and pause.
    func togglePlayback() {
        if isPlaying { pause() } else { play() }
    }

    /// Start the 60fps scroll timer.
    private func startTimer() {
        stopTimer()
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                let increment = CGFloat(self.speed / 60.0)
                let maxOffset = max(0, self.contentHeight - self.viewportHeight)
                self.scrollOffset = min(self.scrollOffset + increment, maxOffset)

                // Auto-pause at the end
                if self.scrollOffset >= maxOffset && maxOffset > 0 {
                    self.pause()
                }
            }
        }
    }

    /// Stop the scroll timer.
    private func stopTimer() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    // MARK: - Navigation

    /// Jump forward by a number of "lines" (each line ≈ fontSize * 1.5).
    func skipForward(lines: Int = 3) {
        let jump = CGFloat(Double(lines) * fontSize * 1.5)
        let maxOffset = max(0, contentHeight - viewportHeight)
        scrollOffset = min(scrollOffset + jump, maxOffset)
    }

    /// Jump backward by a number of "lines" (each line ≈ fontSize * 1.5).
    func rewind(lines: Int = 3) {
        let jump = CGFloat(Double(lines) * fontSize * 1.5)
        scrollOffset = max(scrollOffset - jump, 0)
    }

    /// Reset the scroll position to the top.
    func reset() {
        pause()
        scrollOffset = 0
    }

    // MARK: - Loading

    /// Replace script text with the system clipboard contents.
    func loadFromClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        scriptText = string
        reset()
    }

    /// Present an open panel to load a .txt or .md file as script text.
    func loadFromFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.plainText, .text]
        panel.title = "Load Teleprompter Script"

        if panel.runModal() == .OK, let url = panel.url {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                scriptText = text
                reset()
            }
        }
    }

    /// Clear the current script.
    func clearScript() {
        scriptText = ""
        reset()
    }
}
