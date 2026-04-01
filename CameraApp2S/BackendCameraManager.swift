//
//  CameraManager.swift
//  CameraApp2S
//
//  Created by Nimalan Arulvelan on 3/15/26.
//

import AVFoundation
import UIKit
import SwiftUI
import Combine

/// Main camera manager for microscope functionality
@MainActor
final class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isCameraReady = false
    @Published var isRecording = false
    @Published var focusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus
    @Published var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
    @Published var isLocked = false
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var maxZoomFactor: CGFloat = 1.0
    @Published var capturedImage: UIImage?
    
    // Camera components
    private let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDevice: AVCaptureDevice?
    
    // Session queue for async camera operations
    private let sessionQueue = DispatchQueue(label: "com.cameraapp.sessionqueue")
    
    override init() {
        super.init()
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
    }
    
    // MARK: - Session Configuration
    
    func setupCamera() async {
        guard isAuthorized else { return }
        
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                self.captureSession.beginConfiguration()
                
                // Configure for high-quality photo capture (microscope use)
                self.captureSession.sessionPreset = .photo
                
                // Setup video device (prefer telephoto for microscope)
                guard let videoDevice = self.selectBestCamera() else {
                    self.captureSession.commitConfiguration()
                    continuation.resume()
                    return
                }
                
                self.videoDevice = videoDevice
                
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    
                    if self.captureSession.canAddInput(videoDeviceInput) {
                        self.captureSession.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    }
                    
                    // Setup photo output with high quality settings
                    let photoOutput = AVCapturePhotoOutput()
                    photoOutput.maxPhotoQualityPrioritization = .quality
                    
                    if self.captureSession.canAddOutput(photoOutput) {
                        self.captureSession.addOutput(photoOutput)
                        self.photoOutput = photoOutput
                    }
                    
                    // Configure device for microscope use
                    try videoDevice.lockForConfiguration()
                    
                    // Enable auto focus if available
                    if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                        videoDevice.focusMode = .continuousAutoFocus
                    }
                    
                    // Enable auto exposure
                    if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
                        videoDevice.exposureMode = .continuousAutoExposure
                    }
                    
                    // Set maximum zoom factor
                    Task { @MainActor in
                        self.maxZoomFactor = min(videoDevice.activeFormat.videoMaxZoomFactor, 10.0)
                        self.currentZoomFactor = 1.0
                    }
                    
                    videoDevice.unlockForConfiguration()
                    
                    self.captureSession.commitConfiguration()
                    
                    Task { @MainActor in
                        self.isCameraReady = true
                    }
                    
                } catch {
                    print("Error setting up camera: \(error.localizedDescription)")
                    self.captureSession.commitConfiguration()
                }
                
                continuation.resume()
            }
        }
    }
    
    private func selectBestCamera() -> AVCaptureDevice? {
        // For microscope use, prefer cameras with better zoom capabilities
        if let dualCamera = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
            return dualCamera
        }
        
        if let telephotoCamera = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) {
            return telephotoCamera
        }
        
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }
    
    // MARK: - Session Control
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
    
    func getCaptureSession() -> AVCaptureSession {
        return captureSession
    }
    
    // MARK: - Focus Control
    
    func setFocusMode(_ mode: AVCaptureDevice.FocusMode) {
        guard let device = videoDevice else { return }
        
        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                
                if device.isFocusModeSupported(mode) {
                    device.focusMode = mode
                    Task { @MainActor in
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
        
        sessionQueue.async {
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
                
                device.unlockForConfiguration()
            } catch {
                print("Error setting focus point: \(error.localizedDescription)")
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
                
                device.unlockForConfiguration()
                
                Task { @MainActor in
                    self?.isLocked = true
                }
            } catch {
                print("Error locking focus: \(error.localizedDescription)")
            }
        }
    }
    
    func unlockFocus() {
        guard let device = videoDevice else { return }
        
        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                
                device.unlockForConfiguration()
                
                Task { @MainActor in
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
                
                Task { @MainActor in
                    self?.currentZoomFactor = zoomFactor
                }
            } catch {
                print("Error setting zoom: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }
        
        sessionQueue.async { [weak self] in
            var photoSettings = AVCapturePhotoSettings()
            
            // Use highest quality settings for microscope imaging
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            photoSettings.photoQualityPrioritization = .quality
            
            if let self = self {
                photoOutput.capturePhoto(with: photoSettings, delegate: self)
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error capturing photo: \(error!.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Unable to create image from photo data")
            return
        }
        
        Task { @MainActor in
            self.capturedImage = image
            // Save to photo library
            await PhotoLibraryManager.shared.saveImage(image)
        }
    }
}
