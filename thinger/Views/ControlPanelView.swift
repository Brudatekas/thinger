//
//  ControlPanelView.swift
//  thinger
//
//  A settings/control panel window for programmatically controlling the notch.
//  Provides sliders and buttons for tweaking animation, dimensions, corner radii,
//  timing, and shadow — ideal for taking screenshots and GIFs.
//

import SwiftUI

/// A control panel window for live-tweaking every notch parameter.
///
/// ## Overview
///
/// `ControlPanelView` is presented in its own `Window` scene, opened from the gear icon
/// inside the expanded notch or from the menu bar "Settings…" item. It provides real-time
/// controls over all values centralized in ``NotchConfiguration``.
///
/// ### Sections
///
/// 1. **Notch Controls** — open/close, lock, clear widgets.
/// 2. **Notch Animation** — spring response and damping for the open/close morph.
/// 3. **Dimensions** — minimum open width and height.
/// 4. **Corner Radii** — open/closed top and bottom radii.
/// 5. **Timing** — hover close delay and drag debounce delay.
/// 6. **Shadow** — blur radius and vertical offset.
/// 7. **Widget Animation** — spring response and damping for card transitions.
///
/// A "Reset All to Defaults" button at the bottom restores factory values.
struct ControlPanelView: View {

    @EnvironmentObject var vm: NotchViewModel
    @ObservedObject var config = NotchConfiguration.shared

    var body: some View {
        TabView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    notchControlsSection
                    notchAnimationSection
                    dimensionsSection
                    cornerRadiiSection
                    timingSection
                    shadowSection
                    widgetAnimationSection
                    #if DEBUG
                    debugSection
                    #endif
                    resetSection
                }
                .padding(20)
            }
            .tabItem { Label("Notch", systemImage: "rectangle.topthird.inset.filled") }

            TeleprompterSettingsView(tvm: vm.teleprompterVM)
                .environmentObject(vm)
                .tabItem { Label("Teleprompter", systemImage: "text.justify.leading") }
        }
        .frame(minWidth: 380, idealWidth: 420, minHeight: 500, idealHeight: 700)
    }

    // MARK: - Section: Notch Controls

    private var notchControlsSection: some View {
        SectionCard(title: "Notch Controls", icon: "rectangle.topthird.inset.filled") {
            HStack(spacing: 12) {
                Button {
                    vm.open()
                } label: {
                    Label("Open", systemImage: "arrow.up.left.and.arrow.down.right")
                }

                Button {
                    vm.close()
                } label: {
                    Label("Close", systemImage: "arrow.down.right.and.arrow.up.left")
                }

                Button {
                    vm.toggle()
                } label: {
                    Label("Toggle", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .buttonStyle(.bordered)

            Toggle(isOn: $vm.isLocked) {
                Label("Lock Notch", systemImage: vm.isLocked ? "lock.fill" : "lock.open")
            }
            .toggleStyle(.switch)

            Button(role: .destructive) {
                vm.clearAllBatches()
            } label: {
                Label("Clear All Widgets", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Section: Notch Animation

    private var notchAnimationSection: some View {
        SectionCard(title: "Notch Animation", icon: "waveform.path") {
            SliderRow(
                label: "Spring Response",
                value: $config.notchSpringResponse,
                range: 0.1...1.0,
                step: 0.05,
                format: "%.2f"
            )
            SliderRow(
                label: "Spring Damping",
                value: $config.notchSpringDamping,
                range: 0.1...2.0,
                step: 0.05,
                format: "%.2f"
            )
        }
    }

    // MARK: - Section: Dimensions

    private var dimensionsSection: some View {
        SectionCard(title: "Dimensions", icon: "ruler") {
            SliderRow(
                label: "Min Open Width",
                value: $config.minOpenWidth,
                range: 0...800,
                step: 10,
                format: "%.0f pt"
            )
            SliderRow(
                label: "Min Open Height",
                value: $config.minOpenHeight,
                range: 0...400,
                step: 10,
                format: "%.0f pt"
            )
        }
    }

    // MARK: - Section: Corner Radii

    private var cornerRadiiSection: some View {
        SectionCard(title: "Corner Radii", icon: "square.on.square.squareshape.controlhandles") {
            Group {
                Text("Open State").font(.caption).foregroundStyle(.secondary)
                SliderRow(
                    label: "Top Radius",
                    value: $config.openTopCornerRadius,
                    range: 0...30,
                    step: 1,
                    format: "%.0f"
                )
                SliderRow(
                    label: "Bottom Radius",
                    value: $config.openBottomCornerRadius,
                    range: 0...60,
                    step: 1,
                    format: "%.0f"
                )
            }

            Divider()

            Group {
                Text("Closed State").font(.caption).foregroundStyle(.secondary)
                SliderRow(
                    label: "Top Radius",
                    value: $config.closedTopCornerRadius,
                    range: 0...20,
                    step: 1,
                    format: "%.0f"
                )
                SliderRow(
                    label: "Bottom Radius",
                    value: $config.closedBottomCornerRadius,
                    range: 0...20,
                    step: 1,
                    format: "%.0f"
                )
            }
        }
    }

    // MARK: - Section: Timing

    private var timingSection: some View {
        SectionCard(title: "Timing", icon: "timer") {
            SliderRow(
                label: "Hover Close Delay",
                value: Binding(
                    get: { Double(config.hoverCloseDelay) },
                    set: { config.hoverCloseDelay = Int($0) }
                ),
                range: 0...1000,
                step: 10,
                format: "%.0f ms"
            )
            SliderRow(
                label: "Drag Debounce",
                value: Binding(
                    get: { Double(config.dragDebounceDelay) },
                    set: { config.dragDebounceDelay = Int($0) }
                ),
                range: 0...200,
                step: 5,
                format: "%.0f ms"
            )
        }
    }

    // MARK: - Section: Shadow

    private var shadowSection: some View {
        SectionCard(title: "Shadow", icon: "shadow") {
            SliderRow(
                label: "Blur Radius",
                value: $config.shadowRadius,
                range: 0...50,
                step: 1,
                format: "%.0f"
            )
            SliderRow(
                label: "Y Offset",
                value: $config.shadowOffsetY,
                range: 0...30,
                step: 1,
                format: "%.0f"
            )
        }
    }

    // MARK: - Section: Widget Animation

    private var widgetAnimationSection: some View {
        SectionCard(title: "Widget Animation", icon: "square.stack.3d.up") {
            SliderRow(
                label: "Spring Response",
                value: $config.widgetSpringResponse,
                range: 0.1...1.0,
                step: 0.05,
                format: "%.2f"
            )
            SliderRow(
                label: "Spring Damping",
                value: $config.widgetSpringDamping,
                range: 0.1...2.0,
                step: 0.05,
                format: "%.2f"
            )
        }
    }

    // MARK: - Section: Debug

    #if DEBUG
    private var debugSection: some View {
        SectionCard(title: "Debug", icon: "ant") {
            SliderRow(
                label: "Vertical Offset",
                value: $config.debugVerticalOffset,
                range: 0...200,
                step: 1,
                format: "%.0f pt"
            )
        }
    }
    #endif

    // MARK: - Reset

    private var resetSection: some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                config.resetToDefaults()
            } label: {
                Label("Reset All to Defaults", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - SectionCard

/// A visually grouped card with a title, icon, and stacked content.
private struct SectionCard<Content: View>: View {
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

// MARK: - SliderRow

/// A labeled slider that displays the current numeric value.
private struct SliderRow: View {
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

// MARK: - Preview

#Preview {
    ControlPanelView()
        .environmentObject(NotchViewModel())
}
