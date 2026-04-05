//
//  EnhancementOptionsView.swift
//  CameraApp2S
//
//  Created by Nimalan Arulvelan on 3/15/26.
//

import SwiftUI

/// Manual image enhancement controls
struct EnhancementOptionsView: View {
    let originalImage: UIImage?
    let onEnhanced: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var brightness: Double = 0.0
    @State private var contrast: Double = 1.0
    @State private var saturation: Double = 1.0
    @State private var sharpness: Double = 0.0
    @State private var enableNoiseReduction = true
    @State private var enableEdgeEnhancement = false
    @State private var isProcessing = false
    @State private var previewImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview
                    if let preview = previewImage ?? originalImage {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .background(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    if isProcessing {
                        ProgressView("Processing...")
                            .padding()
                    }
                    
                    // Controls
                    VStack(alignment: .leading, spacing: 16) {
                        // Brightness
                        VStack(alignment: .leading) {
                            Text("Brightness: \(String(format: "%.2f", brightness))")
                                .font(.subheadline)
                            Slider(value: $brightness, in: -1.0...1.0)
                                .onChange(of: brightness) { _, _ in
                                    updatePreview()
                                }
                        }
                        
                        // Contrast
                        VStack(alignment: .leading) {
                            Text("Contrast: \(String(format: "%.2f", contrast))")
                                .font(.subheadline)
                            Slider(value: $contrast, in: 0.0...2.0)
                                .onChange(of: contrast) { _, _ in
                                    updatePreview()
                                }
                        }
                        
                        // Saturation
                        VStack(alignment: .leading) {
                            Text("Saturation: \(String(format: "%.2f", saturation))")
                                .font(.subheadline)
                            Slider(value: $saturation, in: 0.0...2.0)
                                .onChange(of: saturation) { _, _ in
                                    updatePreview()
                                }
                        }
                        
                        // Sharpness
                        VStack(alignment: .leading) {
                            Text("Sharpness: \(String(format: "%.2f", sharpness))")
                                .font(.subheadline)
                            Slider(value: $sharpness, in: 0.0...2.0)
                                .onChange(of: sharpness) { _, _ in
                                    updatePreview()
                                }
                        }
                        
                        Divider()
                        
                        // Toggles
                        Toggle("Noise Reduction", isOn: $enableNoiseReduction)
                            .onChange(of: enableNoiseReduction) { _, _ in
                                updatePreview()
                            }
                        
                        Toggle("Edge Enhancement", isOn: $enableEdgeEnhancement)
                            .onChange(of: enableEdgeEnhancement) { _, _ in
                                updatePreview()
                            }
                        
                        Divider()
                        
                        // Presets
                        Text("Presets")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            Button("Microscope") {
                                applyMicroscopePreset()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("High Contrast") {
                                applyHighContrastPreset()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Reset") {
                                resetValues()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle("Enhance Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyEnhancements()
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }
    
    private func updatePreview() {
        guard let image = originalImage else { return }
        
        isProcessing = true
        
        let options = ImageEnhancementManager.EnhancementOptions(
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            sharpness: sharpness,
            enableNoiseReduction: enableNoiseReduction,
            enableEdgeEnhancement: enableEdgeEnhancement
        )
        
        Task {
            let enhanced = await ImageEnhancementManager.shared.enhance(image, options: options)
            await MainActor.run {
                previewImage = enhanced
                isProcessing = false
            }
        }
    }
    
    private func applyEnhancements() {
        guard let enhanced = previewImage else { return }
        onEnhanced(enhanced)
        dismiss()
    }
    
    private func applyMicroscopePreset() {
        brightness = 0.1
        contrast = 1.2
        saturation = 1.1
        sharpness = 1.0
        enableNoiseReduction = true
        enableEdgeEnhancement = true
        updatePreview()
    }
    
    private func applyHighContrastPreset() {
        brightness = 0.0
        contrast = 1.5
        saturation = 1.0
        sharpness = 1.2
        enableNoiseReduction = true
        enableEdgeEnhancement = false
        updatePreview()
    }
    
    private func resetValues() {
        brightness = 0.0
        contrast = 1.0
        saturation = 1.0
        sharpness = 0.0
        enableNoiseReduction = true
        enableEdgeEnhancement = false
        previewImage = nil
    }
}

#Preview {
    EnhancementOptionsView(originalImage: nil) { _ in }
}
