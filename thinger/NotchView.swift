//
//  NotchView.swift
//  thinger
//
//  The main visual notch container with hover-to-expand behavior.
//  Uses withAnimation(.spring) + a local AnimPhase state for a two-phase morph:
//    Phase 1: closed pill → wider pill (same height)  — spring
//    Phase 2: wider pill → full notch                  — spring (after 150ms delay)
//    Closing: single spring back to closed
//  Top edge is locked to screen top via ZStack .top alignment.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Animation Phase
/// Local animation phase that drives the notch's visual dimensions.
/// Separate from NotchViewModel's state — this controls the visual morph timeline.
enum AnimPhase {
    case closed
    case expanded  // intermediate wider pill (same height)
    case open      // full notch with content
}

// MARK: - NotchView
struct NotchView: View {
    @EnvironmentObject var vm: NotchViewModel
    
    /// Local animation phase driving the visual morph
    @State private var animPhase: AnimPhase = .closed
    
    /// Task for the delayed phase-2 expansion
    @State private var expandTask: Task<Void, Never>?
    
    // MARK: - Dimension Constants
    
    private var currentTopRadius: CGFloat {
        switch animPhase {
        case .closed: return 0
        case .expanded: return 8
        case .open: return 10
        }
    }
    
    private var currentBottomRadius: CGFloat {
        switch animPhase {
        case .closed: return 0
        case .expanded: return 12
        case .open: return 20
        }
    }
    
    /// Closed dimensions come from the hardware notch via NotchDimensions singleton
    private var closedWidth: CGFloat { NotchDimensions.shared.notchWidth }
    private var closedHeight: CGFloat { NotchDimensions.shared.notchHeight }
    private var openWidth: CGFloat { 500 }
    private let openHeight: CGFloat = 180
    
    // MARK: - Computed Dimensions
    
    private var currentWidth: CGFloat {
        switch animPhase {
        case .closed: return closedWidth
        case .expanded, .open: return openWidth
        }
    }
    
    private var currentHeight: CGFloat {
        switch animPhase {
        case .closed, .expanded: return closedHeight
        case .open: return openHeight
        }
    }
    
    
    // MARK: - Body
    
    var body: some View {
        ZStack() {
            Color.black
            ZStack {
                // Content fades in only when fully open
                if animPhase == .open {
                    expandedContent
                        .transition(.opacity)
                }
            }
            .padding(.all, 10)
            // width minus the width of the outward top corners
            .frame(width: currentWidth - currentTopRadius * 2, height: currentHeight)
            // Drag targeting: keeps notch open when files are dragged over the expanded area
            .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: Binding(
                get: { vm.globalDragTargeting },
                set: { vm.updateGlobalDragTargeting($0) }
            )) { _ in
                return false // let individual DropZoneViews handle actual drops
            }
            .onHover { hovering in
                vm.handleHover(hovering)
            }
            
        }
        .frame(width: currentWidth, height: currentHeight, alignment: .top)
        .onChange(of: vm.notchState) { _, newState in
            if newState == .open {
                // Phase 1: widen to full width (height stays)
                withAnimation(.interpolatingSpring(duration: 0.3, bounce: 0.35)) {
                    animPhase = .expanded
                }
                // Phase 2: grow height (width stays) — waits for phase 1 to finish
                expandTask?.cancel()
                expandTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    guard !Task.isCancelled else { return }
                    withAnimation(.interpolatingSpring(duration: 0.35, bounce: 0.4)) {
                        animPhase = .open
                    }
                }
            } else {
                // Closing: exact reverse of opening
                expandTask?.cancel()
                withAnimation(.interpolatingSpring(duration: 0.3, bounce: 0.3)) {
                    animPhase = .expanded
                }
                expandTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    guard !Task.isCancelled else { return }
                    withAnimation(.interpolatingSpring(duration: 0.3, bounce: 0.3)) {
                        animPhase = .closed
                    }
                }
            }
            
        }
        .clipShape(NotchShape(
            topCornerRadius: currentTopRadius,
            bottomCornerRadius: currentBottomRadius
        ))

    }
    
    // MARK: - Expanded Content
    
    private var expandedContent: some View {
        VStack{
            
            HStack {
                Text("hello")
                Spacer()
                Image(systemName: "gear")
            }
            .ignoresSafeArea()
            
            WidgetShelf()
                .environmentObject(vm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
//        .background(Color.red)
        
    }
}

// MARK: - NotchShape
/// Custom shape that mimics the MacBook notch with outward-curved top corners.
/// Animatable via topCornerRadius and bottomCornerRadius for smooth morph transitions.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat
    
    init(topCornerRadius: CGFloat = 6, bottomCornerRadius: CGFloat = 14) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }
    
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY)
        )
        
        path.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius))
        
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY)
        )
        
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY))
        
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY)
        )
        
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius))
        
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY)
        )
        
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Preview
#Preview {
    NotchView()
        .frame(width: 500, height: 180)
        .environmentObject(NotchViewModel())
}
