//
//  AirDropWidgetView.swift
//  thinger
//
//  AirDrop widget that uses the reusable WidgetTrayView for its
//  dashed-border tray and drag-and-drop targeting.
//

import SwiftUI
import UniformTypeIdentifiers

/// A shelf widget that shares dropped files via AirDrop.
///
/// ## Overview
///
/// `AirDropWidgetView` is a permanent fixture on the left side of the ``WidgetShelf``.
/// It renders a wave icon (SF Symbol `wave.3.up`) and an "AirDrop" label inside a
/// ``WidgetTrayView`` tray. When files are dropped on it:
///
/// 1. The `onDropHandler` fires and delegates to ``handleDrop(_:)``.
/// 2. `handleDrop` sets ``isProcessing`` to `true` (for future spinner UI)
///    and calls ``NotchViewModel/handleAirDropDrop(providers:from:)``.
/// 3. The view model extracts file URLs from the providers, then opens the
///    system AirDrop share sheet via `NSSharingService(named: .sendViaAirDrop)`.
///
/// ### Tap-to-Pick (Disabled)
///
/// A file-picker flow (`handleClick`) is implemented but currently commented out.
/// When enabled, tapping the widget would present an `NSOpenPanel` and immediately
/// AirDrop the selected files via ``NotchViewModel/pickFilesForAirDrop(from:)``.
///
/// ## Topics
///
/// ### Actions
/// - ``handleDrop(_:)``
/// - ``handleClick()``
struct AirDropWidgetView: View {

    /// The notch view model that owns the AirDrop sharing logic.
    @EnvironmentObject var vm: NotchViewModel

    /// Whether an AirDrop operation is in progress (reserved for future spinner UI).
    @State private var isProcessing = false

    /// Whether the file picker is currently visible (reserved for the tap-to-pick flow).
    @State private var isPickerOpen = false

    var body: some View {
        WidgetTrayView(onDropHandler: { providers in
            Task { await handleDrop(providers) }
            return true
        }) { isTargeted in
            VStack(spacing: 6) {
                ZStack {
                    Image(systemName: "wave.3.up")
                        .font(.system(size: 20, weight: .light))
                }
                .frame(height: 24)

                Text("AirDrop")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
            }
            .frame(width: 65, height: 80)
        }
//        .onTapGesture {
//            Task{
//                await handleClick()
//            }
//        }
    }

    // MARK: - Actions

    /// Handles a file drop by forwarding the providers to the view model's AirDrop pipeline.
    ///
    /// The method is `async` because ``NotchViewModel/handleAirDropDrop(providers:from:)``
    /// extracts file URLs from `NSItemProvider` instances using `loadItem`, which requires
    /// an asynchronous context.
    ///
    /// - Parameter providers: The `NSItemProvider` array from the drag session.
    private func handleDrop(_ providers: [NSItemProvider]) async {
        print("droppedair")
        isProcessing = true
        defer { isProcessing = false }
        await vm.handleAirDropDrop(providers: providers, from: nil)
    }

    /// Opens a file picker and immediately AirDrops the selected files.
    ///
    /// - Note: This method is currently **unused** (the `.onTapGesture` is commented out).
    ///   It wraps ``NotchViewModel/pickFilesForAirDrop(from:)`` which presents an
    ///   `NSOpenPanel` and then calls ``NotchViewModel/shareToAirDrop(items:from:)``.
    private func handleClick() async {
        isPickerOpen = true
        defer { isPickerOpen = false }

        await MainActor.run {
            vm.pickFilesForAirDrop(from: nil)
        }
    }
}
