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

struct WidgetShelf: View {
    @EnvironmentObject var vm: NotchViewModel

    /// Whether a system-wide drag is happening and a placeholder should appear
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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: vm.batches.count)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPlaceholder)
        // Measure the shelf's intrinsic width and push it to the VM
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: ShelfWidthPreferenceKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(ShelfWidthPreferenceKey.self) { width in
            // Add horizontal padding (10 per side) + some breathing room
            let needed = width + 40
            vm.desiredOpenWidth = max(NotchDimensions.shared.minOpenWidth, needed)
        }

    }

    // MARK: - Placeholder

    private var placeholderWidget: some View {
        PlaceholderDropZone()
            .environmentObject(vm)
    }
}

// MARK: - PlaceholderDropZone

/// A ghost widget that appears when dragging. Dropping files on it creates a real batch.
struct PlaceholderDropZone: View {
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

/// Preference key used to measure the WidgetShelf's intrinsic content width
/// and feed it back to the NotchViewModel for dynamic notch sizing.
private struct ShelfWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
