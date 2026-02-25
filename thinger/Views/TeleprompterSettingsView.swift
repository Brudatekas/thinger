//
//  TeleprompterSettingsView.swift
//  thinger
//
//  Settings tab for teleprompter configuration in the control panel.
//  Uses the same SectionCard/SliderRow pattern as the main settings.
//

import SwiftUI

// MARK: - TeleprompterSettingsView

/// Settings panel for teleprompter configuration.
///
/// ## Overview
///
/// `TeleprompterSettingsView` provides controls for all teleprompter parameters
/// using the same ``SectionCard`` and ``SliderRow`` visual pattern as the main
/// ``ControlPanelView``. It includes:
///
/// 1. **Script** — TextEditor for editing text, load/paste/clear buttons.
/// 2. **Playback** — Speed and font size sliders, play/pause/reset buttons.
/// 3. **Display** — Mirror toggle.
/// 4. **Keyboard Shortcuts** — Read-only reference of available hotkeys.
struct TeleprompterSettingsView: View {

    @EnvironmentObject var vm: NotchViewModel
    @ObservedObject var config = NotchConfiguration.shared
    @ObservedObject var tvm: TeleprompterViewModel

    init(tvm: TeleprompterViewModel? = nil) {
        self._tvm = ObservedObject(wrappedValue: tvm ?? TeleprompterViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                scriptSection
                playbackSection
                displaySection
                shortcutsSection
            }
            .padding(20)
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 500, idealHeight: 700)
    }

    // MARK: - Section: Script

    private var scriptSection: some View {
        TeleprompterSectionCard(title: "Script", icon: "doc.text") {
            TextEditor(text: $tvm.scriptText)
                .font(.system(size: 12))
                .frame(minHeight: 120, maxHeight: 200)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary.opacity(0.3))
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack(spacing: 8) {
                Button {
                    tvm.loadFromClipboard()
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)

                Button {
                    tvm.loadFromFile()
                } label: {
                    Label("Load from File", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) {
                    tvm.clearScript()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Section: Playback

    private var playbackSection: some View {
        TeleprompterSectionCard(title: "Playback", icon: "play.circle") {
            HStack(spacing: 12) {
                Button {
                    tvm.togglePlayback()
                } label: {
                    Label(tvm.isPlaying ? "Pause" : "Play",
                          systemImage: tvm.isPlaying ? "pause.fill" : "play.fill")
                }

                Button {
                    tvm.rewind()
                } label: {
                    Label("Rewind", systemImage: "backward.fill")
                }

                Button {
                    tvm.skipForward()
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                }

                Button {
                    tvm.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
            }
            .buttonStyle(.bordered)

            TeleprompterSliderRow(
                label: "Speed",
                value: $config.teleprompterSpeed,
                range: 10...200,
                step: 5,
                format: "%.0f px/s"
            )

            TeleprompterSliderRow(
                label: "Font Size",
                value: $config.teleprompterFontSize,
                range: 14...72,
                step: 1,
                format: "%.0f pt"
            )
        }
    }

    // MARK: - Section: Display

    private var displaySection: some View {
        TeleprompterSectionCard(title: "Display", icon: "eye") {
            Toggle(isOn: $config.teleprompterMirror) {
                Label("Mirror Text", systemImage: "rectangle.landscape.rotate")
            }
            .toggleStyle(.switch)
        }
    }

    // MARK: - Section: Shortcuts

    private var shortcutsSection: some View {
        TeleprompterSectionCard(title: "Keyboard Shortcuts", icon: "keyboard") {
            VStack(alignment: .leading, spacing: 6) {
                shortcutRow("⌘ Space", "Play / Pause")
                shortcutRow("⌘ ↑", "Increase Speed")
                shortcutRow("⌘ ↓", "Decrease Speed")
                shortcutRow("⌘ →", "Skip Forward")
                shortcutRow("⌘ ←", "Rewind")
                shortcutRow("⌘ R", "Reset to Top")
            }
        }
    }

    private func shortcutRow(_ keys: String, _ action: String) -> some View {
        HStack {
            Text(keys)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 80, alignment: .leading)
            Text(action)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - TeleprompterSectionCard

/// A visually grouped card with a title, icon, and stacked content.
/// Duplicated from ControlPanelView since SectionCard is private there.
struct TeleprompterSectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary.opacity(0.5))
            )
        }
    }
}

// MARK: - TeleprompterSliderRow

/// A labeled slider that displays the current numeric value.
/// Duplicated from ControlPanelView since SliderRow is private there.
struct TeleprompterSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(String(format: format, value))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}
