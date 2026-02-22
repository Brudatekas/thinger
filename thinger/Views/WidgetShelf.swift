//
//  WidgetShelf.swift
//  thinger
//
//  Container that shows DropZoneViews in an HStack.
//  Spawns a placeholder when dragging files over an empty area.
//  Empty widgets auto-remove when the notch closes.
//

import SwiftUI
import UniformTypeIdentifiers

/// The horizontal container that lays out all active widgets inside the expanded notch.
///
/// ## Overview
///
/// `WidgetShelf` is the second-level view inside ``NotchView``'s expanded content.
/// It renders an `HStack` containing:
///
/// 1. **AirDrop widget** — always present as the leftmost item (``AirDropWidgetView``).
/// 2. **Batch widgets** — one ``DropZoneView`` per ``BatchViewModel`` in ``NotchViewModel/batches``.
/// 3. **Placeholder** — a ghost "+" widget (``PlaceholderDropZone``) that appears only
///    when a system-wide drag is active, inviting the user to create a new batch by dropping.
///
/// ### Static Width
///
/// The notch width is controlled by ``NotchConfiguration/minOpenWidth`` — there is no
/// dynamic width measurement. The control panel slider sets the width directly.
///
/// ### Animation
///
/// Widget additions and removals animate with `.spring(response: 0.3, dampingFraction: 0.8)`.
/// Each widget enters/exits with a combined `scale + opacity` transition.
///
/// ## Topics
///
/// ### Widgets
/// - ``AirDropWidgetView``
/// - ``DropZoneView``
/// - ``PlaceholderDropZone``
///
/// ### Sizing
/// - Controlled by ``NotchConfiguration/minOpenWidth``
struct WidgetShelf: View {

    /// The notch view model providing batch data and the `desiredOpenWidth` binding.
    @EnvironmentObject var vm: NotchViewModel

    /// Whether a placeholder "New" widget should be shown.
    ///
    /// Returns `true` when either ``NotchViewModel/globalDragTargeting`` or
    /// ``NotchViewModel/anyDropZoneTargeting`` is active, indicating a system-wide
    /// drag is in progress and the user may want to create a new batch.
    private var showPlaceholder: Bool {
        vm.globalDragTargeting || vm.anyDropZoneTargeting
    }

    var body: some View {
        HStack(spacing: 10) {
            // AirDrop Target Location
            AirDropWidgetView()
                .environmentObject(vm)
                .transition(.scale.combined(with: .opacity))
                
            // Existing batches
            ForEach(Array(vm.batches.enumerated()), id: \.element.id) { _, batch in
                DropZoneView(batch: batch)
                    .environmentObject(vm)
                    .transition(.scale.combined(with: .opacity))
            }

            // Placeholder — appears when dragging files and there's room for a new widget
            if showPlaceholder {
                placeholderWidget
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: NotchConfiguration.shared.widgetSpringResponse, dampingFraction: NotchConfiguration.shared.widgetSpringDamping), value: vm.batches.count)
        .animation(.spring(response: NotchConfiguration.shared.widgetSpringResponse, dampingFraction: NotchConfiguration.shared.widgetSpringDamping), value: showPlaceholder)

    }

    // MARK: - Placeholder

    /// Wraps ``PlaceholderDropZone`` with the current environment.
    private var placeholderWidget: some View {
        PlaceholderDropZone()
            .environmentObject(vm)
    }
}

// MARK: - PlaceholderDropZone

/// A translucent "+" ghost widget that appears when dragging files over the shelf.
///
/// ## Overview
///
/// `PlaceholderDropZone` acts as a factory for new batch widgets. It wraps a simple
/// "+" icon and "New" label inside a ``WidgetTrayView``. When files are dropped on it:
///
/// 1. A new ``BatchViewModel`` is created via ``NotchViewModel/addBatch()``.
/// 2. The dropped providers are forwarded to the new batch's ``BatchViewModel/handleDrop(providers:)``.
///
/// This makes the placeholder self-destructing in a sense: once files are dropped, the
/// placeholder adds a real ``DropZoneView`` to the shelf, and the placeholder itself
/// will disappear if no more drags are active (since ``WidgetShelf/showPlaceholder``
/// becomes `false`).
///
/// - Note: The placeholder is **65 × 80 pt** to roughly match the size of a single
///   ``ItemCard`` in compact mode.
struct PlaceholderDropZone: View {

    /// The notch view model used to create a new batch when files are dropped.
    @EnvironmentObject var vm: NotchViewModel

    var body: some View {
        WidgetTrayView(onDropHandler: { providers in
            let newBatch = vm.addBatch()
            newBatch.handleDrop(providers: providers)
            return true
        }) { isTargeted in
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .light))
                Text("New")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
            }
            .frame(width: 65, height: 80)
        }
    }
}

// MARK: - ShelfWidthPreferenceKey
