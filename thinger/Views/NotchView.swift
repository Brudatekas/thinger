//
//  NotchView.swift
//  thinger
//
//  The main visual notch container with hover-to-expand behavior.
//  A single spring animation grows the notch from its closed pill to full size.
//  Top edge is locked to screen top via ZStack .top alignment.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - NotchView
struct NotchView: View {
    @EnvironmentObject var vm: NotchViewModel
    
    /// Whether the notch is visually expanded (drives dimensions + content)
    @State private var isOpen = false
    
    // MARK: - Dimension Constants
    
    private var currentTopRadius: CGFloat {
        isOpen ? 10 : 0
    }
    
    private var currentBottomRadius: CGFloat {
        isOpen ? 40 : 10
    }
    
    /// Closed dimensions come from the hardware notch via NotchDimensions singleton
    private var closedWidth: CGFloat { NotchDimensions.shared.notchWidth }
    private var closedHeight: CGFloat { NotchDimensions.shared.notchHeight }
    
    // MARK: - Computed Dimensions
    
    private var currentWidth: CGFloat {
        isOpen ? vm.openWidth : closedWidth
    }
    
    private var currentHeight: CGFloat {
        isOpen ? vm.openHeight : closedHeight
    }
    
    
    // MARK: - Body
    
    var body: some View {
        ZStack() {
            Color.black
            ZStack {
                // Content fades in only when open
                if isOpen {
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
        .shadow(color: .black.opacity(isOpen ? 0.5 : 0), radius: 20, x: 0, y: 10)
        .onChange(of: vm.notchState) { _, newState in
            withAnimation(.spring(response: 0.35, dampingFraction: 1)) {
                isOpen = newState == .open
            }
        }
        .containerShape(.rect(cornerRadius: currentBottomRadius))
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
        .frame(width: NotchDimensions.shared.minOpenWidth, height: NotchDimensions.shared.minOpenHeight)
        .environmentObject(NotchViewModel())
}
