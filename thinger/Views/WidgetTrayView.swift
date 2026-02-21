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

struct WidgetTrayView<Content: View>: View {
    @EnvironmentObject var vm: NotchViewModel
    @State private var isTargeted = false

    /// Corner radius for the tray border and fill shape.
    let cornerRadius: CGFloat

    /// Internal padding between content and the tray border.
    let padding: CGFloat

    /// Handler called when items are dropped. Return `true` if the drop is accepted.
    let onDropHandler: ([NSItemProvider]) -> Bool

    /// Content closure receives the current `isTargeted` state so inner
    /// views can react (e.g. adjust icon opacity, label color).
    @ViewBuilder let content: (_ isTargeted: Bool) -> Content

    // MARK: - Defaults

    init(
        cornerRadius: CGFloat = 12,
        padding: CGFloat = 0,
        onDropHandler: @escaping ([NSItemProvider]) -> Bool,
        @ViewBuilder content: @escaping (_ isTargeted: Bool) -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.onDropHandler = onDropHandler
        self.content = content
    }

    // MARK: - Supported UTTypes

    private static var supportedTypes: [UTType] {
        [.fileURL, .url, .utf8PlainText, .plainText, .data]
    }

    // MARK: - Body

    var body: some View {
        content(isTargeted)
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(
                ConcentricRectangle(corners: .concentric, isUniform: true)
                        .stroke(
                            .white.opacity(isTargeted ? 0.3 : 0.12),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
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
