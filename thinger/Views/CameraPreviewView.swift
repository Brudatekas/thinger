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

    /// The capture session to display.
    let session: AVCaptureSession

    /// Whether the preview should be horizontally flipped.
    let isMirrored: Bool

    /// Creates the underlying `NSView` with an embedded preview layer.
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        // Apply mirror if needed
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }

        view.layer?.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        return view
    }

    /// Updates the preview layer when SwiftUI state changes.
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let previewLayer = context.coordinator.previewLayer else { return }

        // Update frame to match view bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = nsView.bounds
        CATransaction.commit()

        // Update mirror state
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
