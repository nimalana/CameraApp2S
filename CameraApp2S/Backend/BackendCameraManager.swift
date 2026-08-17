//
//  CameraManager.swift
//  Microscope Viewer Camera
//
//  Created by Nimalan Arulvelan on 3/15/26.
//

@preconcurrency import AVFoundation
import UIKit
import SwiftUI
import Combine

/// Photo quality presets
enum PhotoQuality: String, CaseIterable, Identifiable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var id: String { rawValue }
}

/// Photo file format. JPEG is the default for universal compatibility;
/// HEIC produces smaller files but isn't readable on every platform.
enum PhotoFormat: String, CaseIterable, Identifiable {
    case jpeg = "JPEG"
    case heic = "HEIC"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .heic: return "heic"
        }
    }
    
    var uti: String {
        switch self {
        case .jpeg: return "public.jpeg"
        case .heic: return "public.heic"
        }
    }
}

/// Main camera manager for microscope functionality
@MainActor
final class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isCameraReady = false
    @Published var isCameraAvailable = true
    @Published var isRecording = false
    @Published var focusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus
    @Published var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
    @Published var isLocked = false
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var maxZoomFactor: CGFloat = 1.0
    @Published var capturedImage: UIImage?
    @Published var isUsingFrontCamera = false
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var currentCameraName: String = ""
    @Published var errorMessage: String?
    @Published var lensPosition: Float = 0.5
    @Published var isAutoFocusEnabled = true
    @Published var supportsFocus = true
    @Published var isVideoMode = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var photoQuality: PhotoQuality = .high
    @Published var photoFormat: PhotoFormat = .jpeg
    @Published var showCaptureFlash = false
    @Published var lastSavedMediaDate = Date()
    @Published var isRefocusing = false
    
    private var recordingTimer: Timer?
    
    // Camera components – accessed on sessionQueue; nonisolated(unsafe) silences
    // main-actor isolation warnings since we manage thread safety via sessionQueue.
    nonisolated(unsafe) private let captureSession = AVCaptureSession()
    nonisolated(unsafe) private var videoDeviceInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private var audioDeviceInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private var photoOutput: AVCapturePhotoOutput?
    nonisolated(unsafe) private var movieFileOutput: AVCaptureMovieFileOutput?
    nonisolated(unsafe) private var videoDevice: AVCaptureDevice?
    
    // Session queue for async camera operations
    private let sessionQueue = DispatchQueue(label: "com.cameraapp.sessionqueue")
    
    // KVO observations for autofocus/autoexposure completion
    private var focusObservation: NSKeyValueObservation?
    private var exposureObservation: NSKeyValueObservation?
    private var lensPositionObservation: NSKeyValueObservation?
    private var tapFocusObservation: NSKeyValueObservation?
    private var tapExposureObservation: NSKeyValueObservation?
    private var tapRefocusID = UUID()
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subjectAreaDidChange),
            name: AVCaptureDevice.subjectAreaDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted),
            name: AVCaptureSession.wasInterruptedNotification,
            object: captureSession
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: AVCaptureSession.interruptionEndedNotification,
            object: captureSession
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError),
            name: AVCaptureSession.runtimeErrorNotification,
            object: captureSession
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc nonisolated private func subjectAreaDidChange(_ notification: Notification) {
        Task { @MainActor in
            resumeContinuousAutoFocus()
        }
    }
    
    @objc nonisolated private func sessionWasInterrupted(_ notification: Notification) {
        Task { @MainActor in
            self.isCameraReady = false
        }
    }
    
    @objc nonisolated private func sessionInterruptionEnded(_ notification: Notification) {
        Task { @MainActor in
            self.isCameraReady = true
        }
    }
    
    @objc nonisolated private func sessionRuntimeError(_ notification: Notification) {
        // Attempt to restart the session on runtime errors
        let session = captureSession
        sessionQueue.async {
            session.startRunning()
        }
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }
        
        // Also request microphone access for video recording
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
    }
    
    // MARK: - Session Configuration
    
    func setupCamera() async {
        guard isAuthorized else { return }
        
        // Discover available cameras
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera, .builtInDualCamera, .builtInTripleCamera],
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discoverySession.devices.sorted {
            CameraManager.sortPriority(for: $0) < CameraManager.sortPriority(for: $1)
        }
        
        guard let defaultDevice = AVCaptureDevice.default(for: .video) else {
            isCameraAvailable = false
            errorMessage = "No camera available on this device."
            return
        }
        
        await configureSession(with: defaultDevice)
    }
    
    private func configureSession(with device: AVCaptureDevice?) async {
        guard let videoDevice = device else { return }
        
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let strongSelf = self else {
                    continuation.resume()
                    return
                }
                
                strongSelf.captureSession.beginConfiguration()
                
                // Remove existing inputs
                if let existingInput = strongSelf.videoDeviceInput {
                    strongSelf.captureSession.removeInput(existingInput)
                }
                if let existingAudio = strongSelf.audioDeviceInput {
                    strongSelf.captureSession.removeInput(existingAudio)
                }
                
                // Use .photo preset so AVCapturePhotoOutput gets the sensor's
                // full still-image resolution. Video recording still works at
                // the active format's natural resolution.
                strongSelf.captureSession.sessionPreset = .photo
                
                strongSelf.videoDevice = videoDevice
                
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    
                    if strongSelf.captureSession.canAddInput(videoDeviceInput) {
                        strongSelf.captureSession.addInput(videoDeviceInput)
                        strongSelf.videoDeviceInput = videoDeviceInput
                    }
                    
                    // Only add photo output if not already added
                    if strongSelf.photoOutput == nil {
                        let photoOutput = AVCapturePhotoOutput()
                        photoOutput.maxPhotoQualityPrioritization = .quality
                        
                        if strongSelf.captureSession.canAddOutput(photoOutput) {
                            strongSelf.captureSession.addOutput(photoOutput)
                            strongSelf.photoOutput = photoOutput
                        }
                    }
                    
                    // Ask the photo output to use the largest still-image
                    // dimensions the current device format supports. Without
                    // this, captures fall back to a smaller default and the
                    // resulting JPEGs are only ~hundreds of KB.
                    if let photoOutput = strongSelf.photoOutput,
                       let maxDim = videoDevice.activeFormat.supportedMaxPhotoDimensions.last {
                        photoOutput.maxPhotoDimensions = maxDim
                    }
                    
                    // Add movie file output for video recording
                    if strongSelf.movieFileOutput == nil {
                        let movieOutput = AVCaptureMovieFileOutput()
                        if strongSelf.captureSession.canAddOutput(movieOutput) {
                            strongSelf.captureSession.addOutput(movieOutput)
                            strongSelf.movieFileOutput = movieOutput
                        }
                    }
                    
                    // Add audio input for video recording
                    if strongSelf.audioDeviceInput == nil,
                       let audioDevice = AVCaptureDevice.default(for: .audio),
                       let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
                       strongSelf.captureSession.canAddInput(audioInput) {
                        strongSelf.captureSession.addInput(audioInput)
                        strongSelf.audioDeviceInput = audioInput
                    }
                    
                    // Start with autofocus to acquire initial focus
                    try videoDevice.lockForConfiguration()
                    
                    if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                        videoDevice.focusMode = .continuousAutoFocus
                    }
                    
                    if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
                        videoDevice.exposureMode = .continuousAutoExposure
                    }
                    
                    videoDevice.unlockForConfiguration()
                    
                    strongSelf.captureSession.commitConfiguration()
                    
                    let deviceSupportsFocus = videoDevice.isFocusModeSupported(.continuousAutoFocus) ||
                        videoDevice.isFocusModeSupported(.autoFocus) ||
                        videoDevice.isFocusModeSupported(.locked)
                    
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.maxZoomFactor = min(videoDevice.activeFormat.videoMaxZoomFactor, 7.0)
                        self.currentZoomFactor = 1.0
                        self.isCameraReady = true
                        self.isUsingFrontCamera = videoDevice.position == .front
                        self.currentCameraName = CameraManager.displayName(for: videoDevice)
                        self.supportsFocus = deviceSupportsFocus
                        self.isAutoFocusEnabled = deviceSupportsFocus
                        self.lensPosition = videoDevice.lensPosition
                        // Observe hardware lens position so the slider tracks autofocus
                        self.observeLensPosition(device: videoDevice)
                        // Lock AE/AF once autofocus finishes acquiring
                        self.observeAndLockWhenReady(device: videoDevice)
                    }
                    
                } catch {
                    strongSelf.captureSession.commitConfiguration()
                    Task { @MainActor [weak self] in
                        self?.errorMessage = "Failed to set up camera: \(error.localizedDescription)"
                    }
                }
                
                continuation.resume()
            }
        }
    }
    
    func switchCamera() async {
        let currentPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        
        let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition)
        await configureSession(with: newDevice)
    }
    
    /// Switch to a specific camera device
    func selectCamera(_ device: AVCaptureDevice) async {
        await configureSession(with: device)
    }
    
    /// Human-readable name for a camera device, matching the labels used by
    /// the native Camera app where possible.
    static func displayName(for device: AVCaptureDevice) -> String {
        if device.position == .front {
            return "Front Camera"
        }
        switch device.deviceType {
        case .builtInUltraWideCamera:
            return "0.5x lens"
        case .builtInWideAngleCamera:
            return "1x lens"
        case .builtInTelephotoCamera:
            return "Telephoto lens"
        case .builtInDualCamera:
            return "Dual lens"
        case .builtInTripleCamera:
            return "Triple lens"
        default:
            return device.localizedName
        }
    }
    
    /// Sort order for camera selection: 1x first, then higher-power lenses
    /// (telephoto/dual/triple), then 0.5x ultra-wide, then any front cameras.
    private static func sortPriority(for device: AVCaptureDevice) -> Int {
        if device.position == .front {
            return 100 // Front cameras last
        }
        switch device.deviceType {
        case .builtInWideAngleCamera:
            return 0  // 1x
        case .builtInTelephotoCamera:
            return 1  // Higher power
        case .builtInDualCamera:
            return 2
        case .builtInTripleCamera:
            return 3
        case .builtInUltraWideCamera:
            return 10 // 0.5x — after higher-power lenses
        default:
            return 50
        }
    }
    
    /// Observe autofocus/autoexposure completion via KVO on initial camera setup.
    /// This does NOT set the user-visible `isLocked` flag — the lock indicator
    /// should only appear when the user explicitly taps the lock button.
    private func observeAndLockWhenReady(device: AVCaptureDevice) {
        // Cancel any existing observations
        focusObservation?.invalidate()
        exposureObservation?.invalidate()
        
        // Track whether both focus and exposure have settled
        var focusSettled = !device.isAdjustingFocus
        var exposureSettled = !device.isAdjustingExposure
        
        let tryLock: () -> Void = { [weak self] in
            guard focusSettled, exposureSettled else { return }
            self?.focusObservation?.invalidate()
            self?.exposureObservation?.invalidate()
            // Don't set isLocked — this is an internal initial settle, not a user action
        }
        
        if focusSettled && exposureSettled {
            return
        }
        
        focusObservation = device.observe(\.isAdjustingFocus, options: [.new]) { _, change in
            if change.newValue == false {
                focusSettled = true
                Task { @MainActor in
                    tryLock()
                }
            }
        }
        
        exposureObservation = device.observe(\.isAdjustingExposure, options: [.new]) { _, change in
            if change.newValue == false {
                exposureSettled = true
                Task { @MainActor in
                    tryLock()
                }
            }
        }
    }
    
    // MARK: - Session Control
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            if !strongSelf.captureSession.isRunning {
                strongSelf.captureSession.startRunning()
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            if strongSelf.captureSession.isRunning {
                strongSelf.captureSession.stopRunning()
            }
        }
    }
    
    func getCaptureSession() -> AVCaptureSession {
        return captureSession
    }
    
    // MARK: - Lens Position Observation
    
    /// Observe the hardware lens position via KVO so the slider tracks autofocus movements
    private func observeLensPosition(device: AVCaptureDevice) {
        lensPositionObservation?.invalidate()
        lensPositionObservation = device.observe(\.lensPosition, options: [.new]) { [weak self] _, change in
            guard let newPosition = change.newValue else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isAutoFocusEnabled else { return }
                self.lensPosition = newPosition
            }
        }
    }
    
    // MARK: - Focus Control
    
    /// Switches to manual focus, syncing the slider to the current hardware
    /// lens position first so the first drag movement responds correctly.
    /// Returns the current lens position for the caller to sync its slider.
    func startManualFocus() -> Float {
        guard let device = videoDevice else { return lensPosition }
        // Some lenses (e.g. fixed-focus ultra-wides on certain devices) don't
        // support locked focus mode — calling setFocusModeLocked would crash.
        guard device.isFocusModeSupported(.locked) else { return device.lensPosition }
        
        let currentPos = device.lensPosition
        isAutoFocusEnabled = false
        lensPosition = currentPos
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.setFocusModeLocked(lensPosition: currentPos)
                device.unlockForConfiguration()
            } catch {
                print("Error starting manual focus: \(error.localizedDescription)")
            }
        }
        
        return currentPos
    }
    
    /// Sets the lens to a specific position (0.0 = nearest, 1.0 = farthest).
    /// Only works when autofocus is disabled.
    func setManualFocusPosition(_ position: Float) {
        guard let device = videoDevice, isCameraReady else { return }
        guard device.isFocusModeSupported(.locked) else { return }
        
        let clampedPosition = min(max(position, 0.0), 1.0)
        
        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                device.setFocusModeLocked(lensPosition: clampedPosition)
                device.unlockForConfiguration()
                
                Task { @MainActor [weak self] in
                    self?.lensPosition = clampedPosition
                    self?.focusMode = .locked
                }
            } catch {
                print("Error setting manual focus: \(error.localizedDescription)")
            }
        }
    }
    
    /// Toggles autofocus on or off. When turning off, the lens stays at its current position.
    func setAutoFocus(_ enabled: Bool) {
        guard let device = videoDevice, supportsFocus else { return }
        
        isAutoFocusEnabled = enabled
        
        if enabled {
            // Switch to continuous autofocus
            sessionQueue.async { [weak self] in
                do {
                    try device.lockForConfiguration()
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                    let pos = device.lensPosition
                    device.unlockForConfiguration()
                    
                    Task { @MainActor [weak self] in
                        self?.lensPosition = pos
                        self?.focusMode = .continuousAutoFocus
                    }
                } catch {
                    print("Error enabling autofocus: \(error.localizedDescription)")
                }
            }
        } else {
            // Lock focus at current position for manual slider control
            guard device.isFocusModeSupported(.locked) else { return }
            sessionQueue.async { [weak self] in
                do {
                    try device.lockForConfiguration()
                    let currentPos = device.lensPosition
                    device.setFocusModeLocked(lensPosition: currentPos)
                    device.unlockForConfiguration()
                    
                    Task { @MainActor [weak self] in
                        self?.lensPosition = currentPos
                        self?.focusMode = .locked
                    }
                } catch {
                    print("Error disabling autofocus: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func setFocusMode(_ mode: AVCaptureDevice.FocusMode) {
        guard let device = videoDevice else { return }
        
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try device.lockForConfiguration()
                
                if device.isFocusModeSupported(mode) {
                    device.focusMode = mode
                    Task { @MainActor [weak self] in
                        self?.focusMode = mode
                    }
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Error setting focus mode: \(error.localizedDescription)")
            }
        }
    }
    
    func setFocusPoint(_ point: CGPoint) {
        guard let device = videoDevice else { return }
        isRefocusing = true
        
        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                
                // Re-enable subject-driven autofocus after tap focus
                device.isSubjectAreaChangeMonitoringEnabled = true
                
                device.unlockForConfiguration()

                let focusSupported = device.isFocusPointOfInterestSupported
                let exposureSupported = device.isExposurePointOfInterestSupported
                
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.watchTapRefocus(
                        device: device,
                        focusSupported: focusSupported,
                        exposureSupported: exposureSupported
                    )
                    self.focusMode = .autoFocus
                    self.isLocked = false
                    self.isAutoFocusEnabled = true
                }
            } catch {
                print("Error setting focus point: \(error.localizedDescription)")
                Task { @MainActor [weak self] in
                    self?.isRefocusing = false
                }
            }
        }
    }

    private func watchTapRefocus(device: AVCaptureDevice, focusSupported: Bool, exposureSupported: Bool) {
        tapFocusObservation?.invalidate()
        tapExposureObservation?.invalidate()
        tapRefocusID = UUID()
        let currentRefocusID = tapRefocusID

        guard focusSupported || exposureSupported else {
            isRefocusing = false
            return
        }

        if focusSupported {
            tapFocusObservation = device.observe(\.isAdjustingFocus, options: [.new]) { [weak self] _, change in
                guard change.newValue == false else { return }
                Task { @MainActor [weak self] in
                    self?.finishTapRefocusIfSettled(device: device, id: currentRefocusID)
                }
            }
        }

        if exposureSupported {
            tapExposureObservation = device.observe(\.isAdjustingExposure, options: [.new]) { [weak self] _, change in
                guard change.newValue == false else { return }
                Task { @MainActor [weak self] in
                    self?.finishTapRefocusIfSettled(device: device, id: currentRefocusID)
                }
            }
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            self?.finishTapRefocusIfSettled(device: device, id: currentRefocusID)
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard self?.tapRefocusID == currentRefocusID else { return }
            self?.endTapRefocus()
        }
    }

    private func finishTapRefocusIfSettled(device: AVCaptureDevice, id: UUID) {
        guard tapRefocusID == id else { return }
        guard !device.isAdjustingFocus, !device.isAdjustingExposure else { return }
        endTapRefocus()
    }

    private func endTapRefocus() {
        tapFocusObservation?.invalidate()
        tapExposureObservation?.invalidate()
        tapFocusObservation = nil
        tapExposureObservation = nil
        isRefocusing = false
    }
    
    /// Called when the subject area changes to return to continuous autofocus
    func resumeContinuousAutoFocus() {
        guard let device = videoDevice else { return }
        // Only resume if not manually locked by the user
        guard !isLocked else { return }
        
        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.isSubjectAreaChangeMonitoringEnabled = false
                
                device.unlockForConfiguration()
                
                Task { @MainActor [weak self] in
                    self?.focusMode = .continuousAutoFocus
                    self?.isAutoFocusEnabled = true
                }
            } catch {
                print("Error resuming continuous autofocus: \(error.localizedDescription)")
            }
        }
    }
    
    func lockFocus() {
        guard let device = videoDevice else { return }
        
        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                
                if device.isFocusModeSupported(.locked) {
                    device.focusMode = .locked
                }
                
                if device.isExposureModeSupported(.locked) {
                    device.exposureMode = .locked
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = false
                device.unlockForConfiguration()
                
                Task { @MainActor [weak self] in
                    self?.isLocked = true
                }
            } catch {
                print("Error locking focus: \(error.localizedDescription)")
            }
        }
    }
    
    func unlockFocus() {
        guard let device = videoDevice else { return }
        let autoFocus = isAutoFocusEnabled
        
        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                
                if autoFocus {
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                }
                // If autofocus is off, leave focus locked at current position
                
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                
                device.unlockForConfiguration()
                
                Task { @MainActor [weak self] in
                    self?.isLocked = false
                }
            } catch {
                print("Error unlocking focus: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Zoom Control
    
    func setZoom(_ factor: CGFloat) {
        guard let device = videoDevice else { return }
        
        let zoomFactor = min(max(factor, 1.0), maxZoomFactor)
        
        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = zoomFactor
                device.unlockForConfiguration()
                
                Task { @MainActor [weak self] in
                    self?.currentZoomFactor = zoomFactor
                }
            } catch {
                print("Error setting zoom: \(error.localizedDescription)")
            }
        }
    }
    
    /// Adjusts zoom by multiplying the current factor by a delta (used for pinch-to-zoom)
    func adjustZoom(by delta: CGFloat) {
        let newZoom = currentZoomFactor * delta
        setZoom(newZoom)
    }
    
    // MARK: - Video Recording
    
    func startRecording() {
        guard let movieFileOutput, !movieFileOutput.isRecording else { return }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        let output = movieFileOutput
        sessionQueue.async { [weak self] in
            guard let self else { return }
            output.startRecording(to: outputURL, recordingDelegate: self)
            Task { @MainActor [weak self] in
                self?.isRecording = true
                self?.recordingDuration = 0
                self?.startRecordingTimer()
            }
        }
    }
    
    func stopRecording() {
        guard let movieFileOutput, movieFileOutput.isRecording else { return }
        let output = movieFileOutput
        sessionQueue.async {
            output.stopRecording()
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recordingDuration += 1.0
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }
        
        // Trigger capture flash feedback
        showCaptureFlash = true
        
        let format = photoFormat
        let output = photoOutput // local copy to avoid capturing nonisolated(unsafe) property
        sessionQueue.async { [weak self] in
            let photoSettings: AVCapturePhotoSettings
            
            switch format {
            case .heic:
                if output.availablePhotoCodecTypes.contains(.hevc) {
                    photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                } else {
                    photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                }
            case .jpeg:
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            }
            
            // Always capture with .quality so Apple's image pipeline produces
            // the best base image. The user's High/Medium/Low setting is
            // applied as a separate re-compression step in the delegate so
            // file sizes are predictable and form a real gradient.
            photoSettings.photoQualityPrioritization = .quality
            
            // Match the photo output's max dimensions so each capture is taken
            // at the sensor's full resolution rather than a smaller default.
            photoSettings.maxPhotoDimensions = output.maxPhotoDimensions
            
            if let strongSelf = self {
                output.capturePhoto(with: photoSettings, delegate: strongSelf)
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            Task { @MainActor in
                self.errorMessage = "Failed to capture photo: \(error.localizedDescription)"
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            Task { @MainActor in
                self.errorMessage = "Unable to process captured photo"
            }
            return
        }
        
        // UIImage is used only for the on-screen thumbnail. The library save
        // uses the raw imageData (re-compressed for Medium/Low) so we control
        // the resulting file size directly.
        let thumbnail = UIImage(data: imageData)
        
        Task { @MainActor in
            self.capturedImage = thumbnail
            let quality = self.photoQuality
            let format = self.photoFormat
            let ext = format.fileExtension
            
            let finalData: Data
            switch quality {
            case .high:
                // Save the pristine sensor output, no re-encoding.
                finalData = imageData
            case .medium:
                finalData = CameraManager.recompress(imageData, format: format, quality: 0.55) ?? imageData
            case .low:
                finalData = CameraManager.recompress(imageData, format: format, quality: 0.25) ?? imageData
            }
            
            await PhotoLibraryManager.shared.saveImageData(finalData, fileExtension: ext)
            self.lastSavedMediaDate = Date()
        }
    }
    
    /// Re-encodes the captured image at the given quality factor. Returns nil
    /// if the source can't be decoded or the destination can't be created.
    nonisolated static func recompress(_ data: Data, format: PhotoFormat, quality: CGFloat) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        
        // Preserve EXIF / orientation metadata from the original
        let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        
        let destinationType: CFString
        switch format {
        case .jpeg:
            destinationType = "public.jpeg" as CFString
        case .heic:
            destinationType = "public.heic" as CFString
        }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            destinationType,
            1,
            nil
        ) else {
            return nil
        }
        
        var properties = metadata
        properties[kCGImageDestinationLossyCompressionQuality] = quality
        
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            self.isRecording = false
            self.stopRecordingTimer()
            
            if let error {
                self.errorMessage = "Failed to record video: \(error.localizedDescription)"
                // Clean up temp file
                try? FileManager.default.removeItem(at: outputFileURL)
                return
            }
            
            // Save video to photo library
            await PhotoLibraryManager.shared.saveVideo(at: outputFileURL)
            
            // Clean up temp file after saving
            try? FileManager.default.removeItem(at: outputFileURL)
            
            // Signal that new media was saved so thumbnail can refresh
            self.lastSavedMediaDate = Date()
        }
    }
}
