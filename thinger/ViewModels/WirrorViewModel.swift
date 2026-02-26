//
//  WirrorViewModel.swift
//  thinger
//
//  ViewModel owning all webcam mirror state: camera session, permission,
//  mirroring, zoom, and brightness. Uses AVFoundation for live preview.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - CameraAuthorizationStatus

/// Human-readable wrapper for camera authorization state.
enum CameraAuthorizationStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
}

// MARK: - WirrorViewModel

/// The brain of the Wirror (webcam mirror) feature.
///
/// ## Overview
///
/// `WirrorViewModel` manages an `AVCaptureSession` that streams the built-in
/// webcam (or any connected camera) into an `AVCaptureVideoPreviewLayer`.
/// The view model handles:
///
/// - Camera permission requests and status tracking
/// - Session start/stop lifecycle tied to tab visibility
/// - Mirror (horizontal flip) toggle
/// - Zoom level control
/// - Brightness overlay control
///
/// ## Topics
///
/// ### Session Lifecycle
/// - ``startSession()``
/// - ``stopSession()``
///
/// ### Configuration
/// - ``isMirrored``
/// - ``zoomLevel``
/// - ``brightnessOverlay``
@MainActor
class WirrorViewModel: ObservableObject {

    // MARK: - Published State

    /// Whether the camera session is actively running.
    @Published var isRunning: Bool = false

    /// Current camera authorization status.
    @Published var authorizationStatus: CameraAuthorizationStatus = .notDetermined

    /// Whether the preview is horizontally mirrored (default: true for a natural mirror).
    @Published var isMirrored: Bool {
        didSet { UserDefaults.standard.set(isMirrored, forKey: "wirror.isMirrored") }
    }

    /// Zoom level (1.0 = no zoom, max 5.0).
    @Published var zoomLevel: Double {
        didSet {
            if zoomLevel.isNaN || zoomLevel.isInfinite {
                zoomLevel = 1.0
            } else if zoomLevel < 1.0 {
                zoomLevel = 1.0
            } else {
                UserDefaults.standard.set(zoomLevel, forKey: "wirror.zoomLevel")
                applyZoom()
            }
        }
    }

    /// Brightness overlay opacity (0.0 = normal, 1.0 = fully dimmed).
    @Published var brightnessOverlay: Double {
        didSet {
            if brightnessOverlay.isNaN || brightnessOverlay.isInfinite {
                brightnessOverlay = 0.0
            } else if brightnessOverlay < 0.0 {
                brightnessOverlay = 0.0
            } else if brightnessOverlay > 1.0 {
                brightnessOverlay = 1.0
            } else {
                UserDefaults.standard.set(brightnessOverlay, forKey: "wirror.brightnessOverlay")
            }
        }
    }

    /// Error message if something goes wrong.
    @Published var errorMessage: String?

    // MARK: - AVFoundation

    /// The capture session driving the camera preview.
    @Published var captureSession: AVCaptureSession?

    /// The currently active video input device.
    private var videoInput: AVCaptureDeviceInput?
    
    /// The video output used to keep the session alive when the preview layer is removed.
    private var videoOutput: AVCaptureVideoDataOutput?

    /// The current video device (for zoom control).
    private var videoDevice: AVCaptureDevice?
    
    /// Task tracking the delayed stop.
    private var scheduledStopTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        self.isMirrored = UserDefaults.standard.object(forKey: "wirror.isMirrored") as? Bool ?? true
        self.zoomLevel = UserDefaults.standard.object(forKey: "wirror.zoomLevel") as? Double ?? 1.0
        self.brightnessOverlay = UserDefaults.standard.object(forKey: "wirror.brightnessOverlay") as? Double ?? 0.0
        checkAuthorization()
    }

    // MARK: - Authorization

    /// Checks the current camera authorization status and updates the published property.
    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationStatus = .authorized
        case .notDetermined:
            authorizationStatus = .notDetermined
        case .denied:
            authorizationStatus = .denied
        case .restricted:
            authorizationStatus = .restricted
        @unknown default:
            authorizationStatus = .denied
        }
    }

    /// Requests camera access. On grant, configures and starts the session.
    func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self = self else { return }
            Task { @MainActor in
                if granted {
                    self.authorizationStatus = .authorized
                    self.configureSession()
                    self.startSession()
                } else {
                    self.authorizationStatus = .denied
                }
            }
        }
    }

    // MARK: - Session Lifecycle

    /// A background actor used to serialize blocking start/stop calls.
    private actor SessionController {
        var session: AVCaptureSession?
        func setSession(_ newSession: AVCaptureSession?) {
            self.session = newSession
        }
        func start() {
            if let session = session, !session.isRunning { session.startRunning() }
        }
        func stop() {
            if let session = session, session.isRunning { session.stopRunning() }
        }
    }
    private let sessionController = SessionController()

    /// Configures the capture session with the default video device.
    private func configureSession() {
        if captureSession == nil {
            let newSession = AVCaptureSession()
            captureSession = newSession
            Task {
                await sessionController.setSession(newSession)
            }
        }
        
        guard let session = captureSession else { return }
        guard session.inputs.isEmpty else { return }

        session.beginConfiguration()
        session.sessionPreset = .medium

        // Find the default camera
        guard let device = AVCaptureDevice.default(for: .video) else {
            errorMessage = "No camera found"
            session.commitConfiguration()
            return
        }

        videoDevice = device

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                videoInput = input
            } else {
                errorMessage = "Cannot add camera input"
            }
            
            // Add a video data output so the session stays active even when the preview layer is removed
            let output = AVCaptureVideoDataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                videoOutput = output
            }
        } catch {
            errorMessage = "Camera error: \(error.localizedDescription)"
        }

        session.commitConfiguration()
    }

    /// Starts the camera capture session on a background thread.
    func startSession() {
        // Cancel any pending stop task since we are starting the session
        scheduledStopTask?.cancel()
        scheduledStopTask = nil

        guard authorizationStatus == .authorized else {
            if authorizationStatus == .notDetermined {
                requestAccess()
            }
            return
        }

        if captureSession == nil || captureSession?.inputs.isEmpty == true {
            configureSession()
        }

        Task {
            await sessionController.start()
            self.isRunning = true
        }
    }

    /// Schedules the session to stop after a delay to conserve battery.
    func scheduleStop() {
        scheduledStopTask?.cancel()
        scheduledStopTask = Task {
            // Keep the camera running for 10 seconds so it can reopen instantly
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            self.stopSession()
        }
    }

    /// Stops the camera capture session.
    func stopSession() {
        scheduledStopTask?.cancel()
        scheduledStopTask = nil

        Task {
            await sessionController.stop()
            await sessionController.setSession(nil)
            self.captureSession = nil
            self.videoInput = nil
            self.videoOutput = nil
            self.videoDevice = nil
            self.isRunning = false
        }
    }

    // MARK: - Zoom

    /// Applies the current zoom level to the video device.
    private func applyZoom() {
#if os(iOS)
        guard let device = videoDevice else { return }
        let clampedZoom = min(max(CGFloat(zoomLevel), 1.0), device.activeFormat.videoMaxZoomFactor)

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedZoom
            device.unlockForConfiguration()
        } catch {
            errorMessage = "Zoom error: \(error.localizedDescription)"
        }
#endif
    }

    // MARK: - Reset

    /// Resets all Wirror settings to defaults.
    func resetToDefaults() {
        isMirrored = true
        zoomLevel = 1.0
        brightnessOverlay = 0.0
    }
}
