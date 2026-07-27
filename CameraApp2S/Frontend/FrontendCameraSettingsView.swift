//
//  CameraSettingsView.swift
//  Microscope Viewer Camera
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
    @AppStorage("preventSleepWhileOpen") private var preventSleepWhileOpen = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Focus") {
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
                    
                    Text("Touch the focus slider for manual focus. Tap the screen to return to autofocus.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                
                Section("Photo Format") {
                    Picker("Format", selection: $cameraManager.photoFormat) {
                        ForEach(PhotoFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    
                    switch cameraManager.photoFormat {
                    case .jpeg:
                        Text("Universal format — viewable and shareable on any device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .heic:
                        Text("Smaller files at similar quality, but not supported on all devices.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Display") {
                    Toggle("Prevent Sleep While Open", isOn: $preventSleepWhileOpen)

                    Text("Keeps the screen awake while the camera is open. The normal sleep timer resumes after leaving the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("About") {
                    LabeledContent("App Version", value: "1.0.0")
                    LabeledContent("Purpose", value: "Microscope Imaging")
                }

                Section("Intended Use") {
                    Text("For educational and hobbyist use only. Not intended for clinical, diagnostic, or medical purposes.")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text("Image fidelity depends on the microscope, adapter, alignment, and lighting. The app applies no transformation or extra magnification beyond what the iPhone camera natively performs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Microscope Mounting") {
                    Link(destination: URL(string: "https://www.thingiverse.com/thing:1768834#files")!) {
                        Label("3D-printable phone microscope adapter", systemImage: "link")
                    }

                    Link(destination: URL(string: "https://www.instructables.com/A-Cheap-Way-to-Stabilize-a-Phone-Camera-for-Micros/")!) {
                        Label("Low-cost phone camera stabilizer guide", systemImage: "link")
                    }
                }
                
                Section("Credits") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Design")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Nimalan Arulvelan and Bob Goldstein")
                            .font(.subheadline)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Developer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Nimalan Arulvelan")
                            .font(.subheadline)
                    }
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
