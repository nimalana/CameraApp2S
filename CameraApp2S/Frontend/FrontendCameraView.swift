//
//  CameraView.swift
//  CameraApp2S
//
//  Created by Nimalan Arulvelan on 3/15/26.
//

import SwiftUI
import AVFoundation

/// Main camera interface for microscope imaging
struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingSettings = false
    @State private var lastPhotoThumbnail: UIImage?
    @State private var showZoomIndicator = false
    @State private var focusSliderValue: Float = 0.5
    
    var body: some View {
        ZStack {
            // Camera Preview
            if cameraManager.isCameraReady {
                CameraPreviewView(
                    session: cameraManager.getCaptureSession(),
                    onTap: { point in
                        // Tapping the screen re-enables autofocus at the tapped point
                        cameraManager.setFocusPoint(point)
                    },
                    onPinchZoom: { delta in
                        cameraManager.adjustZoom(by: delta)
                        showZoomIndicator = true
                    }
                )
                .ignoresSafeArea()
            } else if !cameraManager.isCameraAvailable {
                // No camera on device
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.slash.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.gray)
                            Text("No Camera Available")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            Text("This device does not have a camera.")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
            } else if !cameraManager.isAuthorized && !cameraManager.isCameraReady {
                // Permission denied state
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.gray)
                            Text("Camera Access Required")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            Text("Allow camera access in Settings to capture microscope images.")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                        }
                    }
            } else {
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
            
            // Capture flash feedback
            if cameraManager.showCaptureFlash {
                Color.black
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
            
            // Vertical focus slider on right edge — show for all rear cameras
            if !cameraManager.isUsingFrontCamera {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "flower")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        // Custom vertical focus slider
                        FocusSliderView(
                            value: $focusSliderValue,
                            isAutoFocusEnabled: cameraManager.isAutoFocusEnabled,
                            onChanged: { newValue in
                                cameraManager.setManualFocusPosition(newValue)
                            },
                            onManualFocusStarted: {
                                // Sync slider to current hardware lens position, then switch to manual
                                let currentPos = cameraManager.startManualFocus()
                                focusSliderValue = currentPos
                            }
                        )
                        .accessibilityLabel("Focus")
                        .accessibilityValue("\(Int(focusSliderValue * 100)) percent")
                        .accessibilityHint(cameraManager.isAutoFocusEnabled ? "Touch to switch to manual focus" : "Drag to adjust manual focus")
                        
                        Image(systemName: "mountain.2")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.trailing, 2)
                    .padding(.top, 80)
                    .padding(.bottom, 40)
                }
            }
            
            // Camera Controls Overlay
            VStack {
                // Top Bar
                HStack {
                    // Camera picker menu
                    Menu {
                        ForEach(cameraManager.availableCameras, id: \.uniqueID) { camera in
                            Button {
                                Task {
                                    await cameraManager.selectCamera(camera)
                                }
                            } label: {
                                Label(
                                    CameraManager.displayName(for: camera),
                                    systemImage: "camera.fill"
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "camera.aperture")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Select lens")
                    .accessibilityHint("Choose from available camera lenses")
                    
                    Spacer()
                    
                    // Lock indicator — only show when user has explicitly locked
                    if cameraManager.isLocked {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                            Text("AE/AF Locked")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .accessibilityLabel("Auto-exposure and auto-focus locked")
                    }
                    
                    Spacer()
                    
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Settings")
                }
                .padding()
                
                Spacer()
                
                // Bottom Controls
                VStack(spacing: 16) {
                    // Zoom indicator (appears during pinch)
                    if showZoomIndicator {
                        Text("\(String(format: "%.1f", cameraManager.currentZoomFactor))×")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .transition(.opacity)
                            .accessibilityLabel("Zoom \(String(format: "%.1f", cameraManager.currentZoomFactor)) times")
                    }
                    
                    // Recording duration
                    if cameraManager.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text(formatDuration(cameraManager.recordingDuration))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.6), in: Capsule())
                    }
                    
                    // Photo / Video mode toggle
                    HStack(spacing: 32) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                cameraManager.isVideoMode = false
                            }
                        } label: {
                            Text("PHOTO")
                                .font(.system(size: 16, weight: cameraManager.isVideoMode ? .medium : .bold))
                                .foregroundStyle(cameraManager.isVideoMode ? .white.opacity(0.5) : .yellow)
                        }
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                cameraManager.isVideoMode = true
                            }
                        } label: {
                            Text("VIDEO")
                                .font(.system(size: 16, weight: cameraManager.isVideoMode ? .bold : .medium))
                                .foregroundStyle(cameraManager.isVideoMode ? .yellow : .white.opacity(0.5))
                        }
                    }
                    
                    // Main Action Buttons
                    HStack {
                        // Open Photos app
                        Button {
                            if let url = URL(string: "photos-redirect://") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            if let thumbnail = lastPhotoThumbnail {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.white, lineWidth: 2)
                                    )
                            } else {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(width: 50, height: 50)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .accessibilityLabel("Photo gallery")
                        .accessibilityHint("Opens the Photos app")
                        .frame(maxWidth: .infinity)
                        
                        // Capture / Record Button
                        if cameraManager.isVideoMode {
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                if cameraManager.isRecording {
                                    cameraManager.stopRecording()
                                } else {
                                    cameraManager.startRecording()
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .stroke(.white, lineWidth: 4)
                                        .frame(width: 95, height: 95)
                                    
                                    if cameraManager.isRecording {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(.red)
                                            .frame(width: 36, height: 36)
                                    } else {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 83, height: 83)
                                    }
                                }
                            }
                            .accessibilityLabel(cameraManager.isRecording ? "Stop recording" : "Start recording")
                            .frame(maxWidth: .infinity)
                        } else {
                            Button {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                cameraManager.capturePhoto()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 83, height: 83)
                                    
                                    Circle()
                                        .stroke(.white, lineWidth: 4)
                                        .frame(width: 95, height: 95)
                                }
                            }
                            .accessibilityLabel("Capture photo")
                            .accessibilityHint("Takes a photo")
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Lock/Unlock Button
                        Button {
                            if cameraManager.isLocked {
                                cameraManager.unlockFocus()
                            } else {
                                cameraManager.lockFocus()
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: cameraManager.isLocked ? "lock.fill" : "lock.open.fill")
                                    .font(.title2)
                                Text(cameraManager.isLocked ? "Unlock" : "Lock")
                                    .font(.caption2)
                            }
                            .foregroundStyle(cameraManager.isLocked ? .yellow : .white)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel(cameraManager.isLocked ? "Unlock focus and exposure" : "Lock focus and exposure")
                        .accessibilityHint(cameraManager.isLocked ? "Resumes auto-focus and auto-exposure" : "Locks current focus and exposure settings")
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            CameraSettingsView(cameraManager: cameraManager)
        }
        .task {
            await cameraManager.checkAuthorization()
            if cameraManager.isAuthorized {
                await cameraManager.setupCamera()
                cameraManager.startSession()
            }
            await loadLatestThumbnail()
        }
        .onChange(of: cameraManager.capturedImage) { _, newImage in
            // Use the captured image directly as thumbnail for instant update
            if let newImage {
                lastPhotoThumbnail = newImage
            }
        }
        .onChange(of: cameraManager.lastSavedMediaDate) { _, _ in
            // Refresh thumbnail from photo library after any media is saved (photo or video)
            Task {
                await loadLatestThumbnail()
            }
        }
        .onChange(of: cameraManager.lensPosition) { _, newPosition in
            // Sync slider to actual lens position when autofocus is active
            if cameraManager.isAutoFocusEnabled {
                focusSliderValue = newPosition
            }
        }
        .onChange(of: cameraManager.showCaptureFlash) { _, show in
            if show {
                // Reset the flag after a brief moment
                Task {
                    try? await Task.sleep(for: .seconds(0.15))
                    cameraManager.showCaptureFlash = false
                }
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: cameraManager.currentZoomFactor) { _, _ in
            showZoomIndicator = true
            // Auto-hide after a brief pause
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation {
                    showZoomIndicator = false
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { cameraManager.errorMessage != nil },
            set: { if !$0 { cameraManager.errorMessage = nil } }
        )) {
            Button("OK") { cameraManager.errorMessage = nil }
        } message: {
            Text(cameraManager.errorMessage ?? "")
        }
        .alert("Error", isPresented: Binding(
            get: { PhotoLibraryManager.shared.errorMessage != nil },
            set: { if !$0 { PhotoLibraryManager.shared.errorMessage = nil } }
        )) {
            Button("OK") { PhotoLibraryManager.shared.errorMessage = nil }
        } message: {
            Text(PhotoLibraryManager.shared.errorMessage ?? "")
        }
    }
    
    private func loadLatestThumbnail() async {
        await PhotoLibraryManager.shared.checkAuthorization()
        lastPhotoThumbnail = await PhotoLibraryManager.shared.loadLatestPhotoThumbnail()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    CameraView()
}
