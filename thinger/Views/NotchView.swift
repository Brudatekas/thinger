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

/// The primary visual component that defines the notch's shape, expand/collapse animation,
/// and hosts the widget shelf when expanded.
///
/// ## Overview
///
/// `NotchView` is the root SwiftUI view rendered inside the transparent `NSPanel` managed
/// by `AppDelegate`. It morphs between a small black pill (mimicking the hardware notch)
/// and a larger container that holds the ``WidgetShelf``.
///
/// ### Animation Strategy
///
/// A single spring animation (`.spring(response: 0.35, dampingFraction: 1)`) drives **all**
/// dimensional changes simultaneously — width, height, and both corner radii transition
/// in one pass. This produces a fluid "grow-from-pill" effect.
///
/// ### Layout and Top-Edge Locking
///
/// The parent `NSPanel` is sized to the maximum open dimensions and positioned so its
/// top edge aligns with the screen top. `NotchView` uses `ZStack(alignment: .top)` to
/// ensure the notch shape is pinned to the top — all growth happens **downward**.
///
/// ### Interaction Model
///
/// - **Hover**: `.onHover` delegates to ``NotchViewModel/handleHover(_:)``, which opens
///   the notch immediately and closes it after a 300 ms grace period.
/// - **Drag targeting**: A whole-view `.onDrop` modifier binds to
///   ``NotchViewModel/globalDragTargeting`` so the notch stays open while files hover over
///   the expanded area. Individual ``DropZoneView`` widgets handle actual drops.
/// - **Shadow**: A `.shadow` fades in when the notch opens, giving it depth against the desktop.
///
/// ### Expanded Content
///
/// When open, the notch displays a ``WidgetShelf`` beneath a top toolbar row.
/// Content fades in via a conditional `if isOpen` block with `.transition(.opacity)`.
///
/// - Note: The expanded content's frame is inset by `currentTopRadius` on each side to
///   avoid clipping beneath the outward-curved top corners of ``NotchShape``.
///
/// ## Topics
///
/// ### Related Types
/// - ``NotchShape``
/// - ``WidgetShelf``
/// - ``NotchViewModel``
struct NotchView: View {

    /// The shared view model that owns notch state, targeting counts, and hover logic.
    @EnvironmentObject var vm: NotchViewModel

    /// Centralized tweakable configuration (animation, dimensions, radii).
    @ObservedObject private var config = NotchConfiguration.shared

    /// Action to open the control panel window.
    @Environment(\.openWindow) private var openWindow

    /// Local animation driver — synced to `vm.notchState` via `.onChange`.
    ///
    /// When `vm.notchState` transitions to `.open` or `.closed`, this boolean flips
    /// inside a spring animation block, which in turn drives `currentWidth`,
    /// `currentHeight`, `currentTopRadius`, and `currentBottomRadius`.
    @State private var isOpen = false

    // MARK: - Dimension Constants

    /// Top corner radius for the ``NotchShape`` clip.
    ///
    /// - Returns: ``NotchConfiguration/openTopCornerRadius`` when open, ``NotchConfiguration/closedTopCornerRadius`` when closed.
    private var currentTopRadius: CGFloat {
        isOpen ? CGFloat(config.openTopCornerRadius) : CGFloat(config.closedTopCornerRadius)
    }

    /// Bottom corner radius for the ``NotchShape`` clip.
    ///
    /// - Returns: ``NotchConfiguration/openBottomCornerRadius`` when open, ``NotchConfiguration/closedBottomCornerRadius`` when closed.
    private var currentBottomRadius: CGFloat {
        isOpen ? CGFloat(config.openBottomCornerRadius) : CGFloat(config.closedBottomCornerRadius)
    }

    /// The hardware notch width read from ``NotchDimensions/notchWidth``.
    ///
    /// On non-notch screens this falls back to a reasonable default derived from
    /// the menu bar height.
    private var closedWidth: CGFloat { NotchDimensions.shared.notchWidth }

    /// The hardware notch height read from ``NotchDimensions/notchHeight``.
    private var closedHeight: CGFloat { NotchDimensions.shared.notchHeight }

    // MARK: - Computed Dimensions

    /// The current width of the notch shape, interpolated by the spring animation.
    ///
    /// Open dimensions come from ``NotchViewModel/openWidth`` — a dynamic value that
    /// grows beyond ``NotchDimensions/minOpenWidth`` when the shelf needs more space.
    private var currentWidth: CGFloat {
        isOpen ? vm.openWidth : closedWidth
    }

    /// The current height of the notch shape, interpolated by the spring animation.
    private var currentHeight: CGFloat {
        isOpen ? vm.openHeight : closedHeight
    }

    /// The mouse location converted to local NotchView coordinates.
    private var localMouseLocation: CGPoint {
        if let screen = NSScreen.main {
            let windowX = screen.frame.midX - vm.openWidth / 2
            let mouseX = vm.globalMouseLocation.x
            let mouseY = vm.globalMouseLocation.y
            
            return CGPoint(
                x: mouseX - windowX,
                y: screen.frame.maxY - mouseY
            )
        }
        return .zero
    }

    // MARK: - Body

    var body: some View {
        ZStack {
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
        .shadow(color: .black.opacity(isOpen ? 0.5 : 0), radius: config.shadowRadius, x: 0, y: config.shadowOffsetY)
        .onChange(of: vm.notchState) { _, newState in
            withAnimation(config.notchSpring) {
                isOpen = newState == .open
            }
        }
        .containerShape(.rect(cornerRadius: currentBottomRadius))
        .clipShape(NotchShape(
            topCornerRadius: currentTopRadius,
            bottomCornerRadius: currentBottomRadius
        ))
        .mask {
            VStack(spacing: 0) {
                if vm.isMenuBarRevealed {
                    Rectangle()
                        .frame(maxWidth: .infinity)
                        .frame(height: closedHeight)
                        .background(Color.white)
                        .overlay(alignment: .center) {
                            Capsule()
                                .fill(Color.black) // This cuts the hole
                                .frame(width: 60, height: closedHeight)
                                .position(CGPoint(x: localMouseLocation.x, y: closedHeight / 2))
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
                Rectangle()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Expanded Content

    /// The content shown inside the notch when it is open.
    ///
    /// Layout:
    /// 1. A top toolbar `HStack` with a placeholder label and a settings gear icon.
    /// 2. A ``WidgetShelf`` that fills the remaining space with drag-and-drop widgets.
    ///
    /// The `VStack` is aligned `.topLeading` and fills all available space so widgets
    /// can distribute themselves horizontally within the shelf.
    private var expandedContent: some View {
        VStack{
            
            HStack {
                // Empty HStack that acts as the bounds for the masking hole
            }
            .frame(maxWidth: .infinity)
            .frame(height: vm.isMenuBarRevealed ? closedHeight : 0)
            .background(
                Color.black // Match the notch background
            )

            HStack {
                // Left side — tab picker
                if !vm.globalDragTargeting {
                    Picker("", selection: $vm.activeNotchTab) {
                        Image(systemName: "tray").tag(NotchTab.shelf)
                        Image(systemName: "text.justify.leading").tag(NotchTab.teleprompter)
                        Image(systemName: "web.camera").tag(NotchTab.wirror)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                    .colorMultiply(.white)
                    .transition(.opacity)
                }

                Spacer()
                    .frame(minWidth: closedWidth)

                // Right side — gear menu
                if !vm.globalDragTargeting {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            vm.toggleMenuBarRevealed()
                        }
                    } label: {
                        Image(systemName: "roller.shade.open")
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                    
                    Menu {
                        Button {
                            vm.toggle()
                        } label: {
                            Label("Toggle Notch", systemImage: "rectangle.topthird.inset.filled")
                        }
    
                        Button {
                            vm.toggleLock()
                        } label: {
                            Label(vm.isLocked
                                  ? "Unlock Notch"
                                  : (vm.notchState == .open ? "Lock Open" : "Lock Closed"),
                                  systemImage: vm.isLocked ? "lock.open" : "lock.fill")
                        }
    
                        Divider()
    
                        Button {
                            vm.clearAllBatches()
                        } label: {
                            Label("Clear All Widgets", systemImage: "trash")
                        }
    
                        Divider()
    
                        Button {
                            openWindow(id: "control-panel")
                            NSApp.setActivationPolicy(.regular)
                            NSApp.activate(ignoringOtherApps: true)
                        } label: {
                            Label("Control Panel", systemImage: "slider.horizontal.3")
                        }
    
                        Divider()
    
                        Button {
                            NSApplication.shared.terminate(nil)
                        } label: {
                            Label("Quit Thinger", systemImage: "power")
                        }
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 16, height: 16)
                    .transition(.opacity)
                }
            }
            .ignoresSafeArea()

            switch vm.activeNotchTab {
            case .shelf:
                WidgetShelf()
                    .environmentObject(vm)
            case .teleprompter:
                TeleprompterView()
                    .environmentObject(vm)
                    .environmentObject(vm.teleprompterVM)
            case .wirror:
                WirrorView()
                    .environmentObject(vm)
                    .environmentObject(vm.wirrorVM)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

    }
}

// MARK: - NotchShape

/// A custom `Shape` that draws the characteristic MacBook notch outline — a rectangle
/// with outward-curving "ears" at the top corners and inward-rounded bottom corners.
///
/// ## Overview
///
/// `NotchShape` uses quadratic Bézier curves to produce the notch silhouette.
/// Both `topCornerRadius` and `bottomCornerRadius` are **animatable**, so the shape
/// morphs smoothly between the closed pill (small radii) and the open expanded notch
/// (larger radii) during ``NotchView``'s spring animation.
///
/// ### Geometry
///
/// The path traces the following outline:
///
/// ```
///  ╭─────────┬─────────────────────────┬─────────╮  ← top edge, outward ears
///  │         │                         │         │
///  │         │      content area       │         │
///  │         │                         │         │
///  │         ╰──────┐           ┌──────╯         │
///  ╰────────────────╰───────────╯────────────────╯  ← bottom, inward radii
/// ```
///
/// The ears are formed by quadratic curves whose control points sit at the
/// outer-top corners. The bottom corners are standard inward rounds.
///
/// - Parameter topCornerRadius: Controls the size of the outward-curving "ears".
///   `0` produces a flat top edge (closed state), `10` produces visible ears (open).
/// - Parameter bottomCornerRadius: Controls the inward rounding at the bottom.
///   `10` for the closed pill, `40` for the expanded notch.
///
/// ## Topics
///
/// ### Animatable Conformance
/// - ``animatableData``
struct NotchShape: Shape {

    /// Radius of the outward top-corner "ear" curves. Animatable.
    var topCornerRadius: CGFloat

    /// Radius of the inward bottom-corner curves. Animatable.
    var bottomCornerRadius: CGFloat

    /// Creates a notch shape with the given corner radii.
    ///
    /// - Parameters:
    ///   - topCornerRadius: Defaults to `6` (the hardware notch's physical ear radius).
    ///   - bottomCornerRadius: Defaults to `14` (the hardware notch's physical bottom radius).
    init(topCornerRadius: CGFloat = 6, bottomCornerRadius: CGFloat = 14) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    /// Pairs both radii for SwiftUI animation interpolation.
    ///
    /// SwiftUI reads and writes this property on every animation frame to
    /// produce the intermediate shape between the closed and open states.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    /// Draws the notch path within the given rectangle.
    ///
    /// The path consists of:
    /// 1. A start at `(minX, minY)` — the outer-left top corner.
    /// 2. A quadratic curve forming the **left ear** (outward curve down to `topCornerRadius`).
    /// 3. A vertical line down the left side to `maxY - bottomCornerRadius`.
    /// 4. A quadratic curve forming the **bottom-left inward round**.
    /// 5. A horizontal line across the bottom.
    /// 6. A quadratic curve forming the **bottom-right inward round**.
    /// 7. A vertical line up the right side.
    /// 8. A quadratic curve forming the **right ear** (outward curve back to top).
    /// 9. `closeSubpath()` seals the shape.
    ///
    /// - Parameter rect: The bounding rectangle provided by SwiftUI's layout system.
    /// - Returns: The completed `Path` representing the notch silhouette.
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
