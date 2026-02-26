# Wirror (Webcam Mirror)

@Metadata {
    @PageColor(blue)
}

A detailed technical breakdown of the live webcam preview feature embedded within the Thinger notch.

## Overview

The "Wirror" (Webcam Mirror) feature transforms the expanded notch into a quick-access, live camera preview. It is designed to act as a lightweight digital mirror, allowing users to check their appearance, framing, or lighting before jumping into a video call, without needing to open a dedicated heavyweight application like Photo Booth or QuickTime.

The feature is encapsulated entirely within the ``WirrorView`` UI component and is driven by the ``WirrorViewModel``, which manages the underlying hardware communication via `AVFoundation`.

## Architecture & Data Flow

The architecture is split into three main layers:

1. **Hardware / AVFoundation Layer**: 
    - Managed exclusively by ``WirrorViewModel``.
    - Uses an `AVCaptureSession` to orchestrate data flow.
    - Connects an `AVCaptureDeviceInput` (the default webcam) to an `AVCaptureVideoDataOutput`.
2. **Bridge Layer**: 
    - The ``CameraPreviewView`` struct acts as an `NSViewRepresentable` bridge.
    - It embeds an `AVCaptureVideoPreviewLayer` into the SwiftUI view hierarchy, feeding the raw video buffer directly to the screen via CoreAnimation. 
3. **UI Layer**: 
    - The ``WirrorView`` renders the container, error banners, permission prompts, and the interactive control overlays (Mirror, Zoom, Dim).

```
┌────────────────────────────────────────────────────────┐
│ UI: WirrorView                                         │
│  ├─ Permission Prompts                                 │
│  ├─ Interactive Controls (Zoom, Dim, Mirror, Stop)     │
│  └─ CameraPreviewView (NSViewRepresentable)            │
│      └─ AVCaptureVideoPreviewLayer                     │
│               │                                        │
│               ▼                                        │
│ ViewModel: WirrorViewModel                             │
│  ├─ State: isRunning, authorizationStatus, properties  │
│  └─ AVCaptureSession                                   │
│      ├─ Input: AVCaptureDeviceInput (Webcam)           │
│      └─ Output: AVCaptureVideoDataOutput               │
└────────────────────────────────────────────────────────┘
```

## Key Technical Details

### Lazy Initialization

To maintain Thinger's footprint as a lightweight background utility, the camera hardware is **never pre-warmed**. The `AVCaptureSession` is defined as an optional variable and is only instantiated inside `configureSession()` exactly when the user switches to the Wirror tab. 

### Seamless Tab Switching (The "Stay-On" Buffer)

When the user switches away from the Wirror tab (e.g., clicking back to the Shelf drop zone), SwiftUI destroys the `WirrorView`, which in turn destroys the `CameraPreviewView` and the attached `AVCaptureVideoPreviewLayer`.

Normally, removing a session's only output/preview layer causes AVFoundation to automatically pause the hardware (turning off the green camera light). This causes a jarring, flashing effect if the user rapidly switches back and forth between tabs.

To solve this, the architecture implements two strategies:
1. **Dummy Output**: An `AVCaptureVideoDataOutput` is attached to the session during configuration. Even when the preview layer is destroyed, this data output keeps the session "busy", preventing the hardware loop from pausing.
2. **Delayed Shutdown (`scheduleStop`)**: When `.onDisappear` fires on `WirrorView`, it calls `scheduleStop()` rather than `stopSession()`. This creates a local `Task.sleep` for 5 seconds. If the user navigates back within that window, the `.onAppear` trigger cancels the shutdown task, allowing the camera to reappear instantly without cold-booting the hardware. If the 5 seconds elapse, `stopSession()` is invoked, memory is released, and the green camera light turns off to save battery.

### Hardware Control

Adjustments to the camera feed are piped directly into the hardware configuration when possible to save CPU resources:
- **Mirroring**: Handled at the rendering layer via `AVCaptureConnection.isVideoMirrored = isMirrored`.
- **Zoom**: Handled natively by adjusting the physical `AVCaptureDevice.videoZoomFactor` property (protected by `lockForConfiguration()`).
- **Dimming**: Handled at the UI layer by rendering a black SwiftUI `.opacity()` overlay on top of the preview layer. 

## Future Improvements & Ideas

While the current implementation is stable and feature-rich, there are several areas where the Wirror feature could be expanded in the future:

* **Conditional Video Output Attachment**: Currently, the `AVCaptureVideoDataOutput` is bound to the session immediately during `configureSession()`. This means CPU cycles are spent processing CMSampleBuffers even while the preview layer is actively visible. A more efficient approach would be to only `addOutput()` inside `.onDisappear`, and `removeOutput()` inside `.onAppear`. This would guarantee the "stay-on" effect while completely eliminating background buffer waste when the user is actively viewing the camera.
* **Aspect Ratio Selection**: The current implementation forces `.resizeAspectFill`. Adding a toggle to switch to `.resizeAspect` (letterboxed) would allow users to see the full uncropped sensor output.
* **Camera Selection Picker**: Automatically detect secondary attached webcams (e.g., iPhone Continuity Camera, external USB webcams) and populate them in a dropdown menu within the bottom control bar, allowing users to switch sources.
* **Screen Recording/Snapshot**: Introduce a button to capture a still frame of the current buffer and dump it directly onto the Thinger shelf widget as a draggable image file.
