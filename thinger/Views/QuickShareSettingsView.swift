//
//  QuickShareSettingsView.swift
//  thinger
//

import SwiftUI
import AppKit

/// A dedicated settings tab for tweaking which macOS sharing services
/// are allowed to appear in the notch when dragging files.
struct QuickShareSettingsView: View {
    @EnvironmentObject var vm: NotchViewModel
    @ObservedObject var config = NotchConfiguration.shared
    
    // Dynamically loaded system sharing services
    @State private var availableServices: [NSSharingService] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionCard(title: "Active Share Services", icon: "square.and.arrow.up") {
                    Text("Select which macOS sharing services should dynamically appear when you drag files to the notch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                    
                    if availableServices.isEmpty {
                        Text("Loading services...")
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    } else {
                        ForEach(availableServices, id: \.title) { service in
                            Toggle(isOn: Binding(
                                get: { !config.disabledShareServices.contains(service.title) },
                                set: { isEnabled in
                                    if !isEnabled {
                                        if !config.disabledShareServices.contains(service.title) {
                                            config.disabledShareServices.append(service.title)
                                        }
                                    } else {
                                        config.disabledShareServices.removeAll { $0 == service.title }
                                    }
                                }
                            )) {
                                HStack(spacing: 8) {
                                    Image(nsImage: service.image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                    Text(service.title)
                                }
                            }
                            .toggleStyle(.switch)
                        }
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            loadServices()
        }
    }
    
    /// Loads a generic list of sharing services available on the system.
    private func loadServices() {
        // Fetch services using dummy data that represents common files
        let dummyItems: [Any] = [
            URL(string: "https://apple.com")!,
            "Text",
            NSImage()
        ]
        
        // This prompts macOS to return the services registered for basic item types.
        let services = NSSharingService.sharingServices(forItems: dummyItems)
        
        // Remove duplicates if any (NSSharingService can return multiple for the same app sometimes)
        var unique = [String: NSSharingService]()
        for service in services {
            if unique[service.title] == nil {
                unique[service.title] = service
            }
        }
        
        // Map to an array and sort by title
        self.availableServices = Array(unique.values).sorted { $0.title < $1.title }
    }
}

#Preview {
    QuickShareSettingsView()
        .environmentObject(NotchViewModel())
}
