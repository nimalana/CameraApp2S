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
                    Button {
                        showingGallery = true
                    } label: {
                        Image(systemName: "photo.stack")
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
                            Text("Locked")
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
                    HStack(spacing: 40) {
                        // Lock/Unlock Button
                        Button {
                            if cameraManager.isLocked {
                                cameraManager.unlockFocus()
                            } else {
                                cameraManager.lockFocus()
                            }
                        } label: {
                            VStack {
                                Image(systemName: cameraManager.isLocked ? "lock.fill" : "lock.open.fill")
                                    .font(.title2)
                                Text(cameraManager.isLocked ? "Unlock" : "Lock")
                                    .font(.caption)
                            }
                            .foregroundStyle(cameraManager.isLocked ? .yellow : .white)
                            .frame(width: 70, height: 70)
                            .background(.ultraThinMaterial, in: Circle())
                        }
                        
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
                        
                        // Focus Mode Toggle
                        Button {
                            toggleFocusMode()
                        } label: {
                            VStack {
                                Image(systemName: focusModeIcon)
                                    .font(.title2)
                                Text(focusModeText)
                                    .font(.caption)
                            }
                            .foregroundStyle(.white)
                            .frame(width: 70, height: 70)
                            .background(.ultraThinMaterial, in: Circle())
                        }
                    }
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
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    private var focusModeIcon: String {
        switch cameraManager.focusMode {
        case .continuousAutoFocus:
            return "circle.hexagongrid.fill"
        case .autoFocus:
            return "scope"
        case .locked:
            return "scope"
        @unknown default:
            return "circle.hexagongrid.fill"
        }
    }
    
    private var focusModeText: String {
        switch cameraManager.focusMode {
        case .continuousAutoFocus:
            return "Auto"
        case .autoFocus, .locked:
            return "Manual"
        @unknown default:
            return "Auto"
        }
    }
    
    private func toggleFocusMode() {
        if cameraManager.focusMode == .continuousAutoFocus {
            cameraManager.setFocusMode(.autoFocus)
        } else {
            cameraManager.setFocusMode(.continuousAutoFocus)
        }
    }
}

#Preview {
    CameraView()
}
