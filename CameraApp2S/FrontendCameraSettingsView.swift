//
//  CameraSettingsView.swift
//  CameraApp2S
//
//  Created by Nimalan Arulvelan on 3/15/26.
//

import SwiftUI
import AVFoundation

/// Settings panel for camera configuration
@MainActor
struct CameraSettingsView: View {
    @ObservedObject var cameraManager: CameraManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Focus") {
                    Picker("Focus Mode", selection: focusMode) {
                        Text("Continuous Auto").tag(AVCaptureDevice.FocusMode.continuousAutoFocus)
                        Text("Auto Focus").tag(AVCaptureDevice.FocusMode.autoFocus)
                        Text("Locked").tag(AVCaptureDevice.FocusMode.locked)
                    }
                    .onChange(of: focusMode.wrappedValue) { _, newValue in
                        cameraManager.setFocusMode(newValue)
                    }
                    
                    Toggle("Lock Focus & Exposure", isOn: Binding(
                        get: { cameraManager.isLocked },
                        set: { isLocked in
                            if isLocked {
                                cameraManager.lockFocus()
                            } else {
                                cameraManager.unlockFocus()
                            }
                        }
                    ))
                }
                
                Section("Zoom") {
                    VStack(alignment: .leading) {
                        Text("Current Zoom: \(String(format: "%.1fx", cameraManager.currentZoomFactor))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("Maximum Zoom: \(String(format: "%.1fx", cameraManager.maxZoomFactor))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Image Quality") {
                    Text("High Quality Mode")
                    Text("Photo resolution optimized for microscope imaging")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("About") {
                    LabeledContent("App Version", value: "1.0.0")
                    LabeledContent("Purpose", value: "Microscope Imaging")
                }
            }
            .navigationTitle("Camera Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var focusMode: Binding<AVCaptureDevice.FocusMode> {
        Binding(
            get: { cameraManager.focusMode },
            set: { _ in }
        )
    }
}

#Preview {
    CameraSettingsView(cameraManager: CameraManager())
}
