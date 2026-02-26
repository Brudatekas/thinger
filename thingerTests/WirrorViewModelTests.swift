//
//  WirrorViewModelTests.swift
//  thingerTests
//
//  Aggressive tests for the Wirror (webcam mirror) feature view model.
//

import Testing
import Foundation
import AVFoundation
@testable import thinger

@MainActor
struct WirrorViewModelTests {
    
    private func makeCleanVM() -> WirrorViewModel {
        UserDefaults.standard.removeObject(forKey: "wirror.isMirrored")
        UserDefaults.standard.removeObject(forKey: "wirror.zoomLevel")
        UserDefaults.standard.removeObject(forKey: "wirror.brightnessOverlay")
        return WirrorViewModel()
    }
    
    // MARK: - Edge Cases & Invalid Inputs
    
    @Test("Zoom level should not accept values below 1.0")
    func testZoomLevelLowerBound() async throws {
        let vm = makeCleanVM()
        
        // Attempt to set an invalid negative zoom
        vm.zoomLevel = -5.0
        
        // The property itself should clamp or protect against invalid bounds,
        // because the UI binds directly to it. If it stays -5.0, the UI might break.
        #expect(vm.zoomLevel >= 1.0, "Zoom level should not allow values < 1.0 to be stored in the property")
    }
    
    @Test("Zoom level should not accept values like NaN or Infinity")
    func testZoomLevelNaNInfinity() async throws {
        let vm = makeCleanVM()
        
        vm.zoomLevel = Double.nan
        #expect(!vm.zoomLevel.isNaN, "Zoom level should reject NaN")
        
        vm.zoomLevel = Double.infinity
        #expect(!vm.zoomLevel.isInfinite, "Zoom level should reject Infinity")
    }
    
    @Test("Brightness overlay should be clamped between 0.0 and 1.0")
    func testBrightnessOverlayBounds() async throws {
        let vm = makeCleanVM()
        
        vm.brightnessOverlay = -0.5
        #expect(vm.brightnessOverlay >= 0.0, "Brightness should not be negative")
        
        vm.brightnessOverlay = 1.5
        #expect(vm.brightnessOverlay <= 1.0, "Brightness should not exceed 1.0")
    }
    
    // MARK: - Concurrency & Stress Tests
    
    @Test("Rapid start/stop cycles should not cause race conditions or inconsistent states")
    func testRapidStartStopStress() async throws {
        let vm = makeCleanVM()
        
        // We simulate the system being fully authorized to bypass the permission prompt
        vm.authorizationStatus = .authorized
        
        // Fire off 100 rapid concurrent start/stop requests to stress the Task.detached logic
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await MainActor.run {
                        if i % 2 == 0 {
                            vm.startSession()
                        } else {
                            vm.stopSession()
                        }
                    }
                }
            }
        }
        
        // Give detached tasks a brief moment to settle
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // The state should be logically consistent. 
        // AVCaptureSession's actual running state should match the VM's published state.
        #expect(vm.isRunning == (vm.captureSession?.isRunning ?? false), "Published isRunning state desynced from actual AVCaptureSession state")
    }
    
    @Test("Calling startSession while already running should be a safe no-op")
    func testMultipleStartSessionCalls() async throws {
        let vm = makeCleanVM()
        vm.authorizationStatus = .authorized
        
        vm.startSession()
        try await Task.sleep(nanoseconds: 100_000_000)
        let initialTaskCount = vm.captureSession?.inputs.count ?? 0 // Keep track of configured inputs
        
        // Call it 10 more times
        for _ in 0..<10 {
            vm.startSession()
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Should not have duplicated inputs or crashed
        #expect((vm.captureSession?.inputs.count ?? 0) == initialTaskCount, "Multiple start calls should not re-add inputs")
    }
    
    @Test("Calling stopSession while already stopped should be a safe no-op")
    func testMultipleStopSessionCalls() async throws {
        let vm = makeCleanVM()
        
        #expect(vm.isRunning == false)
        #expect((vm.captureSession?.isRunning ?? false) == false)
        
        // Call it repeatedly
        for _ in 0..<10 {
            vm.stopSession()
        }
        
        try await Task.sleep(nanoseconds: 50_000_000)
        
        #expect(vm.isRunning == false)
        #expect((vm.captureSession?.isRunning ?? false) == false)
    }
    
    // MARK: - State Integrity
    
    @Test("resetToDefaults does not accidentally start or stop the session")
    func testResetDoesNotAffectRunningState() async throws {
        let vm = makeCleanVM()
        vm.authorizationStatus = .authorized
        
        vm.startSession()
        try await Task.sleep(nanoseconds: 100_000_000) // allow start to process
        
        let wasRunning = vm.isRunning
        
        // Malicious edge case check: does resetting defaults mess with the camera?
        vm.resetToDefaults()
        
        #expect(vm.isRunning == wasRunning, "resetToDefaults should not change the running state of the session")
    }
}
