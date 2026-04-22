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
    @State private var showingGallery = false
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
            
            // Vertical focus slider on right edge
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "flower")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    // Vertical slider (rotated Slider)
                    Slider(value: $focusSliderValue, in: 0.0...1.0)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 200, height: 30)
                        .tint(.yellow)
                        .onChange(of: focusSliderValue) { _, newValue in
                            cameraManager.setManualFocusPosition(newValue)
                        }
                        .accessibilityLabel("Focus")
                        .accessibilityValue("\(Int(focusSliderValue * 100)) percent")
                        .accessibilityHint("Adjusts manual focus distance")
                    
                    Image(systemName: "mountain.2")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    // Auto focus reset button
                    if cameraManager.isManualFocus {
                        Button {
                            cameraManager.resetToAutoFocus()
                        } label: {
                            Text("AF")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.black)
                                .frame(width: 30, height: 30)
                                .background(.yellow, in: Circle())
                        }
                        .accessibilityLabel("Reset to auto-focus")
                        .padding(.top, 4)
                    }
                }
                .padding(.trailing, 8)
                .padding(.vertical, 80)
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
                                    systemImage: camera.position == .front ? "camera.front.fill" : "camera.fill"
                                )
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.rotate.fill")
                                .font(.title2)
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Select camera")
                    .accessibilityHint("Choose from available cameras")
                    
                    Spacer()
                    
                    // Lock indicator
                    if cameraManager.isLocked {
                        HStack {
                            Image(systemName: "lock.fill")
                            Text("AE/AF Locked")
                        }
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .padding(8)
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
                VStack(spacing: 20) {
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
                    
                    // Main Action Buttons
                    HStack {
                        // Gallery thumbnail
                        Button {
                            showingGallery = true
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
                        .accessibilityHint("Opens the photo gallery")
                        .frame(maxWidth: .infinity)
                        
                        // Capture Button
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            cameraManager.capturePhoto()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 70, height: 70)
                                
                                Circle()
                                    .stroke(.white, lineWidth: 3)
                                    .frame(width: 80, height: 80)
                            }
                        }
                        .accessibilityLabel("Capture photo")
                        .accessibilityHint("Takes a photo")
                        .frame(maxWidth: .infinity)
                        
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
        .sheet(isPresented: $showingGallery) {
            GalleryView()
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
        .onChange(of: showingGallery) { _, isShowing in
            // Refresh thumbnail when gallery is dismissed (photo may have been deleted)
            if !isShowing {
                Task {
                    await loadLatestThumbnail()
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
}

#Preview {
    CameraView()
}
