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
    @State private var selectedZoom: CGFloat = 1.0
    @State private var lastPhotoThumbnail: UIImage?
    
    var body: some View {
        ZStack {
            // Camera Preview
            if cameraManager.isCameraReady {
                CameraPreviewView(session: cameraManager.getCaptureSession()) { point in
                    cameraManager.setFocusPoint(point)
                }
                .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
            }
            
            // Camera Controls Overlay
            VStack {
                // Top Bar
                HStack {
                    // Camera switch button
                    Button {
                        Task {
                            await cameraManager.switchCamera()
                        }
                    } label: {
                        Image(systemName: "camera.rotate.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    
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
                }
                .padding()
                
                Spacer()
                
                // Bottom Controls
                VStack(spacing: 20) {
                    // Zoom Control
                    VStack(spacing: 8) {
                        Text("Zoom: \(String(format: "%.1fx", selectedZoom))")
                            .font(.caption)
                            .foregroundStyle(.white)
                        
                        HStack {
                            Text("1×")
                                .font(.caption2)
                                .foregroundStyle(.white)
                            
                            Slider(value: $selectedZoom, in: 1.0...cameraManager.maxZoomFactor)
                                .tint(.yellow)
                                .onChange(of: selectedZoom) { _, newValue in
                                    cameraManager.setZoom(newValue)
                                }
                            
                            Text("\(Int(cameraManager.maxZoomFactor))×")
                                .font(.caption2)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: 300)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
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
                        .frame(maxWidth: .infinity)
                        
                        // Capture Button
                        Button {
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
    }
    
    private func loadLatestThumbnail() async {
        await PhotoLibraryManager.shared.checkAuthorization()
        lastPhotoThumbnail = await PhotoLibraryManager.shared.loadLatestPhotoThumbnail()
    }
}

#Preview {
    CameraView()
}
