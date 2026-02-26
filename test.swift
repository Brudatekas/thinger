import AVFoundation
func test() {
    print(AVCaptureDevice.isStudioLightSupported)
    AVCaptureDevice.studioLightControlMode = .app
    AVCaptureDevice.isStudioLightEnabled = true
}
