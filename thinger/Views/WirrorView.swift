//
//  WirrorView.swift
//  thinger
//
//  The webcam mirror display shown inside the expanded notch when the
//  Wirror tab is active. Shows a live camera preview with controls for
//  mirroring, zoom, and brightness.
//

import SwiftUI
import AVFoundation

// MARK: - WirrorView

/// A live webcam mirror display for the notch's expanded content area.
///
/// ## Overview
///
/// `WirrorView` renders a live camera feed using ``CameraPreviewView`` and
/// overlays minimal controls. The view has three states:
///
/// 1. **Not Determined** — Shows a button to request camera access.
/// 2. **Denied / Restricted** — Shows an error message with a link to System Settings.
/// 3. **Authorized** — Shows the live camera feed with a brightness overlay and controls.
///
/// The camera session starts automatically when the view appears (and the tab is active)
/// and stops when the view disappears to conserve resources.
///
/// ## Topics
///
/// ### Related Types
/// - ``WirrorViewModel``
/// - ``CameraPreviewView``
struct WirrorView: View {

    @EnvironmentObject var vm: NotchViewModel

    @EnvironmentObject var wvm: WirrorViewModel

    var body: some View {
        ZStack {
            switch wvm.authorizationStatus {
            case .notDetermined:
                permissionPrompt
            case .denied, .restricted:
                deniedState
            case .authorized:
                cameraContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            wvm.startSession()
        }
        .onDisappear {
            wvm.scheduleStop()
        }
    }

    // MARK: - Permission Prompt

    private var permissionPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "web.camera")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.4))

            Text("Camera Access Required")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Text("Wirror needs camera access to show your webcam preview.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)

            Button {
                wvm.requestAccess()
            } label: {
                Label("Enable Camera", systemImage: "camera.fill")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.6))
        }
    }

    // MARK: - Denied State

    private var deniedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.red.opacity(0.6))

            Text("Camera Access Denied")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Text("Open System Settings → Privacy & Security → Camera to grant access.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)

            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.6))
        }
    }

    // MARK: - Camera Content

    private var cameraContent: some View {
        ZStack {
            // Live camera preview
            if let session = wvm.captureSession {
                CameraPreviewView(
                    session: session,
                    isMirrored: wvm.isMirrored
                )
                .clipShape(ContainerRelativeShape())
            } else {
                ContainerRelativeShape()
                    .fill(Color.black.opacity(0.8))
            }

            // Brightness overlay
            if wvm.brightnessOverlay > 0 {
                ContainerRelativeShape()
                    .fill(.black.opacity(wvm.brightnessOverlay * 0.8))
                    .allowsHitTesting(false)
            }

            // Error banner
            if let error = wvm.errorMessage {
                VStack {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red.opacity(0.7), in: Capsule())
                    Spacer()
                }
                .padding(.top, 4)
            }

            // Bottom controls overlay
            VStack {
                topControls
                Spacer()
                bottomControls
            }
        }
    }

    // MARK: - Bottom Controls
    private var topControls: some View {
        HStack(spacing: 12) {
            Spacer()
            Button {
                wvm.stopSession()
            } label: {
                Image(systemName: "stop.circle.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 12) {
            // Mirror toggle
            Button {
                wvm.isMirrored.toggle()
            } label: {
                Image(systemName: wvm.isMirrored ? "arrow.left.and.right.righttriangle.left.righttriangle.right.fill" : "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Toggle Mirror")

            Spacer()

            // Zoom indicator
            if wvm.zoomLevel > 1.0 {
                Text(String(format: "%.1f×", wvm.zoomLevel))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Zoom controls
            Button {
                wvm.zoomLevel = max(1.0, wvm.zoomLevel - 0.5)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Zoom Out")

            Button {
                wvm.zoomLevel = min(5.0, wvm.zoomLevel + 0.5)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Zoom In")

            Spacer()

            // Brightness control
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    wvm.brightnessOverlay = wvm.brightnessOverlay > 0 ? 0 : 0.3
                }
            } label: {
                Image(systemName: wvm.brightnessOverlay > 0 ? "sun.min.fill" : "sun.max.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Toggle Dim")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(ContainerRelativeShape())
        )
    }
}
