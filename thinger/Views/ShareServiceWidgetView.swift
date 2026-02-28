//
//  ShareServiceWidgetView.swift
//  thinger
//

import SwiftUI
import AppKit

/// A shelf widget that shares dropped files via a specific `NSSharingService`.
///
/// ## Overview
///
/// `ShareServiceWidgetView` dynamically represents an installed system sharing service 
/// (e.g., Mail, AirDrop, Messages). It is instantiated by ``WidgetShelf`` when a drag 
/// involving files enters the notch area, substituting the static AirDrop widget 
/// to offer contextual sharing options based on the dragged file types.
///
/// It renders the service's icon and title inside a ``WidgetTrayView``. When files are
/// dropped on it, it delegates to ``NotchViewModel/handleServiceDrop(providers:service:from:)``
/// to execute the share.
struct ShareServiceWidgetView: View {
    
    /// The notch view model that owns the sharing logic.
    @EnvironmentObject var vm: NotchViewModel
    
    /// The specific macOS sharing service this widget represents (e.g. Mail, AirDrop).
    let service: NSSharingService
    
    /// Whether a share operation is currently being processed.
    @State private var isProcessing = false

    var body: some View {
        WidgetTrayView(onDropHandler: { providers in
            Task { await handleDrop(providers) }
            return true
        }) { isTargeted in
            VStack(spacing: 6) {
                ZStack {
                    Image(nsImage: service.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                .frame(height: 24)

                Text(service.title)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 65, height: 80)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) async {
        isProcessing = true
        defer { isProcessing = false }
        await vm.handleServiceDrop(providers: providers, service: service, from: nil)
    }
}
