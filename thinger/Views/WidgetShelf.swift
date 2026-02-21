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
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.white.opacity(isTargeted ? 0.7 : 0.3))
            Text("New")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(isTargeted ? 0.6 : 0.25))
        }
        .frame(width: 65, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    .white.opacity(isTargeted ? 0.3 : 0.12),
                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(isTargeted ? 0.06 : 0.0))
                )
        )
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: Binding(
            get: { isTargeted },
            set: { targeted in
                isTargeted = targeted
                vm.reportTargetingChange(targeted)
            }
        )) { providers in
            // Create a new batch and drop into it
            let newBatch = vm.addBatch()
            vm.dropEvent = true
            newBatch.handleDrop(providers: providers)
            return true
        }
    }
}
