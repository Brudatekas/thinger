//
//  CameraPreviewView.swift
//  thinger
//
//  An NSViewRepresentable that wraps an AVCaptureVideoPreviewLayer
//  for displaying the live camera feed inside SwiftUI.
//

import SwiftUI
import AVFoundation

// MARK: - CameraPreviewView

/// An `NSViewRepresentable` bridge that embeds an `AVCaptureVideoPreviewLayer`
/// into SwiftUI's view hierarchy.
///
/// ## Overview
///
/// `CameraPreviewView` takes an `AVCaptureSession` and wraps it in an
/// `NSView` containing a `AVCaptureVideoPreviewLayer`. The layer uses
/// `.resizeAspectFill` video gravity so the feed fills the available space
/// without letterboxing.
///
/// The `isMirrored` parameter controls horizontal flipping via a
/// `CATransform3D` on the preview layer's connection, producing a
/// natural mirror effect.
struct CameraPreviewView: NSViewRepresentable {

    /// The persistent preview layer to display.
    let previewLayer: AVCaptureVideoPreviewLayer

    /// Whether the preview should be horizontally flipped.
    let isMirrored: Bool

    /// Creates the underlying `NSView` and attaches the persistent preview layer.
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true

        // Apply mirror if needed
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            // Check if connection requires mirrored state
            connection.isVideoMirrored = isMirrored
        }

        view.layer?.addSublayer(previewLayer)
        
        return view
    }

    /// Updates the preview layer when SwiftUI state changes.
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update frame to match view bounds
        CATransaction.begin()
        // Disable actions so resizing window doesn't animate lag
        CATransaction.setDisableActions(true)
        previewLayer.frame = nsView.bounds
        CATransaction.commit()

        // Update mirror state
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }
    }
    
    // Safely unbind from the nsView so the layer can be re-bound later
    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        if let sublayers = nsView.layer?.sublayers {
            for layer in sublayers where layer is AVCaptureVideoPreviewLayer {
                layer.removeFromSuperlayer()
            }
        }
    }
}
