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
                    Toggle("Auto Focus", isOn: Binding(
                        get: { cameraManager.isAutoFocusEnabled },
                        set: { cameraManager.setAutoFocus($0) }
                    ))
                    
                    Toggle("Lock AE/AF", isOn: Binding(
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
                    Picker("Photo Quality", selection: $cameraManager.photoQuality) {
                        ForEach(PhotoQuality.allCases) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    }
                    
                    switch cameraManager.photoQuality {
                    case .high:
                        Text("Best quality, larger file size. Recommended for microscope imaging.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .medium:
                        Text("Balanced quality and file size.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .low:
                        Text("Smallest file size, faster capture. Lower detail.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
}

#Preview {
    CameraSettingsView(cameraManager: CameraManager())
}
