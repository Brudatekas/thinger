//
//  WidgetTrayView.swift
//  thinger
//
//  Reusable tray wrapper for drag-and-drop widgets.
//  Provides the shared dashed border, background fill, and onDrop
//  targeting logic. The border color changes when the tray is targeted.
//

import SwiftUI
import UniformTypeIdentifiers

/// A generic, reusable tray container that provides the shared drag-and-drop chrome
/// for every widget on the shelf.
///
/// ## Overview
///
/// `WidgetTrayView` is a ``View`` wrapper that encapsulates three pieces of visual and
/// behavioral logic that **every** drag-and-drop widget in the shelf needs:
///
/// 1. **Dashed border** — a `ConcentricRectangle` stroke with a dashed pattern
///    (`[5, 3]`) that brightens from 12 % → 30 % white when targeted.
/// 2. **Drop acceptance** — an `.onDrop` modifier configured for `.fileURL`, `.url`,
///    `.utf8PlainText`, `.plainText`, and `.data`.
/// 3. **Targeting feedback** — a synchronous `Binding` that updates
///    ``NotchViewModel/reportTargetingChange(_:)`` instantly when the targeting state
///    changes, preventing race conditions with debounced close logic.
///
/// ### Synchronous Binding Strategy
///
/// Instead of using `.onChange(of: isTargeted)` (which fires asynchronously on the next
/// run-loop tick), the tray uses a `Binding` setter that **synchronously** calls
/// `vm.reportTargetingChange` and sets `vm.dropEvent`. This is critical because:
/// - The notch's close timer checks `anyDropZoneTargeting` immediately.
/// - An async update could allow a one-frame gap where `anyDropZoneTargeting == false`,
///   causing the notch to close prematurely.
///
/// ### Content Closure
///
/// The `@ViewBuilder` content closure receives the current `isTargeted` state as its
/// only parameter. Inner views can use this to adjust their appearance (e.g., brighten
/// an icon, change label opacity) in response to a drag hovering over the tray.
///
/// ### Consumers
///
/// - ``AirDropWidgetView`` — wraps its icon + label.
/// - ``PlaceholderDropZone`` — wraps the "+" ghost widget.
/// - ``DropZoneView`` — wraps its card stack and controls.
///
/// ## Topics
///
/// ### Configuration
/// - ``cornerRadius``
/// - ``padding``
/// - ``onDropHandler``
///
/// ### Supported Types
/// - ``supportedTypes``
struct WidgetTrayView<Content: View>: View {

    /// The notch view model used to report targeting changes.
    @EnvironmentObject var vm: NotchViewModel

    /// Local targeting state, synced to the `.onDrop` modifier via a ``Binding``.
    @State private var isTargeted = false

    /// Corner radius for the tray's dashed border and background fill shape.
    ///
    /// Defaults to `12` — consistent with the ``ItemCard`` and ``NotchShape`` aesthetic.
    let cornerRadius: CGFloat

    /// Internal padding between the content and the tray border.
    ///
    /// Defaults to `0`. ``DropZoneView`` passes `5` for extra breathing room around
    /// the card stack.
    let padding: CGFloat

    /// Closure invoked when items are dropped onto the tray.
    ///
    /// - Parameter providers: The `NSItemProvider` array from the system drag session.
    /// - Returns: `true` if the drop was accepted; `false` to reject it.
    let onDropHandler: ([NSItemProvider]) -> Bool

    /// Content closure that receives the current `isTargeted` state so inner views
    /// can react to drag-over events (e.g., adjust icon scale, label opacity).
    @ViewBuilder let content: (_ isTargeted: Bool) -> Content

    // MARK: - Defaults

    /// Creates a tray with the specified configuration.
    ///
    /// - Parameters:
    ///   - cornerRadius: The corner radius for the border shape. Defaults to `12`.
    ///   - padding: Internal padding between content and border. Defaults to `0`.
    ///   - onDropHandler: Called when items are dropped. Return `true` to accept.
    ///   - content: A `@ViewBuilder` receiving the `isTargeted` boolean.
    init(
        cornerRadius: CGFloat = NotchVisualConfig.containerCornerRadius,
        padding: CGFloat = NotchVisualConfig.widgetTrayPadding,
        onDropHandler: @escaping ([NSItemProvider]) -> Bool,
        @ViewBuilder content: @escaping (_ isTargeted: Bool) -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.onDropHandler = onDropHandler
        self.content = content
    }

    // MARK: - Supported UTTypes

    /// The set of UTTypes this tray registers for via `.onDrop`.
    ///
    /// Includes `.fileURL`, `.url`, `.utf8PlainText`, `.plainText`, and `.data`
    /// to cover files dragged from Finder, URLs from browsers, and text selections.
    private static var supportedTypes: [UTType] {
        [.fileURL, .url, .utf8PlainText, .plainText, .data]
    }

    // MARK: - Body

    var body: some View {
        content(isTargeted)
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(
                ContainerRelativeShape()
                        .stroke(
                            .white.opacity(isTargeted ? 0.3 : 0.12),
                            style: StrokeStyle(lineWidth: NotchVisualConfig.borderLineWidth, dash: NotchVisualConfig.borderDashPattern)
                        )
              
                
            )
            .onDrop(of: Self.supportedTypes, isTargeted: Binding(
                get: { isTargeted },
                set: { targeted in
                    isTargeted = targeted
                    vm.reportTargetingChange(targeted)
                }
            )) { providers in
                vm.dropEvent = true
                return onDropHandler(providers)
            }
            .foregroundStyle(.white.opacity(isTargeted ? 0.7 : 0.3))
    }
}
