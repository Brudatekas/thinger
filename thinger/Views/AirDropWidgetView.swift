//
//  AirDropWidgetView.swift
//  thinger
//
//  AirDrop widget that uses the reusable WidgetTrayView for its
//  dashed-border tray and drag-and-drop targeting.
//

import SwiftUI
import UniformTypeIdentifiers

struct AirDropWidgetView: View {
    @EnvironmentObject var vm: NotchViewModel
    
    @State private var isProcessing = false
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

    private func handleDrop(_ providers: [NSItemProvider]) async {
        print("droppedair")
        isProcessing = true
        defer { isProcessing = false }
        await vm.handleAirDropDrop(providers: providers, from: nil)
    }
    
    private func handleClick() async {
        isPickerOpen = true
        defer { isPickerOpen = false }
        
        await MainActor.run {
            vm.pickFilesForAirDrop(from: nil)
        }
    }
}
