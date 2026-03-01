import SwiftUI

/// Centralised visual constants for the Notch UI.
struct NotchVisualConfig {
    // MARK: - Corner radii
    static let containerCornerRadius: CGFloat = 12          // used for ContainerRelativeShape()
    static let itemCardCornerRadiusCompact: CGFloat = 8
    static let itemCardCornerRadiusExpanded: CGFloat = 10

    // MARK: - Padding / spacing
    static let widgetTrayPadding: CGFloat = 0
    static let widgetTrayContentPadding: CGFloat = 5
    static let bottomControlsHorizontalPadding: CGFloat = 10
    static let bottomControlsVerticalPadding: CGFloat = 6

    // MARK: - Stroke / dash
    static let borderLineWidth: CGFloat = 1.5
    static let borderDashPattern: [CGFloat] = [5, 3]

    // MARK: - Aspect ratio
    static let cameraPreviewAspectRatio: CGFloat = 1.0 // square preview

    // MARK: - Brightness overlay
    static let brightnessOverlayOpacityFactor: CGFloat = 0.8
}
