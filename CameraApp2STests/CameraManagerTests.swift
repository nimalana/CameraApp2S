//
//  CameraManagerTests.swift
//  Microscope Viewer Camera Tests
//
//  Created by Nimalan Arulvelan on 4/5/26.
//

import Testing
import AVFoundation
@testable import CameraApp2S

struct CameraManagerTests {
    
    // MARK: - Initial State
    
    @MainActor
    @Test func cameraManagerStartsWithCorrectDefaults() {
        let manager = CameraManager()
        #expect(manager.isAuthorized == false)
        #expect(manager.isCameraReady == false)
        #expect(manager.isLocked == true)
        #expect(manager.currentZoomFactor == 1.0)
        #expect(manager.maxZoomFactor == 1.0)
        #expect(manager.capturedImage == nil)
        #expect(manager.isUsingFrontCamera == false)
        #expect(manager.focusMode == .continuousAutoFocus)
        #expect(manager.exposureMode == .continuousAutoExposure)
    }
    
    // MARK: - Zoom Clamping
    
    @MainActor
    @Test func zoomFactorDefaultsToOne() {
        let manager = CameraManager()
        #expect(manager.currentZoomFactor == 1.0)
    }
    
    // MARK: - Available Cameras
    
    @MainActor
    @Test func availableCamerasStartsEmpty() {
        let manager = CameraManager()
        #expect(manager.availableCameras.isEmpty)
    }
}
