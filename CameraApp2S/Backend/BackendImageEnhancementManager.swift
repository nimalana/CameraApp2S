//
//  ImageEnhancementManager.swift
//  CameraApp2S
//
//  Created by Nimalan Arulvelan on 3/15/26.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Handles image enhancement for microscope imaging
class ImageEnhancementManager {
    static let shared = ImageEnhancementManager()
    
    private let context = CIContext()
    
    private init() {}
    
    // MARK: - Enhancement Options
    
    struct EnhancementOptions {
        var brightness: Double = 0.0          // -1.0 to 1.0
        var contrast: Double = 1.0            // 0.0 to 2.0
        var saturation: Double = 1.0          // 0.0 to 2.0
        var sharpness: Double = 0.0           // 0.0 to 2.0
        var enableNoiseReduction: Bool = true
        var enableEdgeEnhancement: Bool = false
    }
    
    // MARK: - Auto Enhancement
    
    func autoEnhance(_ image: UIImage) async -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        return await Task.detached {
            let filters = ciImage.autoAdjustmentFilters()
            var enhancedImage = ciImage
            
            for filter in filters {
                filter.setValue(enhancedImage, forKey: kCIInputImageKey)
                if let output = filter.outputImage {
                    enhancedImage = output
                }
            }
            
            return self.convertToUIImage(enhancedImage)
        }.value
    }
    
    // MARK: - Manual Enhancement
    
    func enhance(_ image: UIImage, options: EnhancementOptions) async -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        return await Task.detached {
            var processedImage = ciImage
            
            // Apply color controls (brightness, contrast, saturation)
            if let colorFilter = CIFilter(name: "CIColorControls") {
                colorFilter.setValue(processedImage, forKey: kCIInputImageKey)
                colorFilter.setValue(options.brightness, forKey: kCIInputBrightnessKey)
                colorFilter.setValue(options.contrast, forKey: kCIInputContrastKey)
                colorFilter.setValue(options.saturation, forKey: kCIInputSaturationKey)
                
                if let output = colorFilter.outputImage {
                    processedImage = output
                }
            }
            
            // Apply sharpness for microscope detail enhancement
            if options.sharpness > 0, let sharpnessFilter = CIFilter(name: "CISharpenLuminance") {
                sharpnessFilter.setValue(processedImage, forKey: kCIInputImageKey)
                sharpnessFilter.setValue(options.sharpness, forKey: kCIInputSharpnessKey)
                
                if let output = sharpnessFilter.outputImage {
                    processedImage = output
                }
            }
            
            // Apply noise reduction (important for microscope images)
            if options.enableNoiseReduction, let noiseFilter = CIFilter(name: "CINoiseReduction") {
                noiseFilter.setValue(processedImage, forKey: kCIInputImageKey)
                noiseFilter.setValue(0.02, forKey: "inputNoiseLevel")
                noiseFilter.setValue(0.4, forKey: "inputSharpness")
                
                if let output = noiseFilter.outputImage {
                    processedImage = output
                }
            }
            
            // Apply edge enhancement for cellular structures
            if options.enableEdgeEnhancement, let edgeFilter = CIFilter(name: "CIEdges") {
                edgeFilter.setValue(processedImage, forKey: kCIInputImageKey)
                edgeFilter.setValue(1.0, forKey: kCIInputIntensityKey)
                
                if let edges = edgeFilter.outputImage {
                    // Blend edges with original
                    if let blendFilter = CIFilter(name: "CIAdditionCompositing") {
                        blendFilter.setValue(edges, forKey: kCIInputImageKey)
                        blendFilter.setValue(processedImage, forKey: kCIInputBackgroundImageKey)
                        
                        if let output = blendFilter.outputImage {
                            processedImage = output
                        }
                    }
                }
            }
            
            return self.convertToUIImage(processedImage)
        }.value
    }
    
    // MARK: - Microscope Specific Enhancements
    
    /// Enhances microscope images with optimal settings for cellular detail
    func enhanceForMicroscopy(_ image: UIImage) async -> UIImage? {
        let options = EnhancementOptions(
            brightness: 0.1,
            contrast: 1.2,
            saturation: 1.1,
            sharpness: 1.0,
            enableNoiseReduction: true,
            enableEdgeEnhancement: true
        )
        
        return await enhance(image, options: options)
    }
    
    // MARK: - Histogram Equalization
    
    func equalizeHistogram(_ image: UIImage) async -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        return await Task.detached {
            // Use tone curve for histogram equalization effect
            if let filter = CIFilter(name: "CIToneCurve") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                
                // Adjust tone curve for better contrast
                filter.setValue(CIVector(x: 0, y: 0), forKey: "inputPoint0")
                filter.setValue(CIVector(x: 0.25, y: 0.3), forKey: "inputPoint1")
                filter.setValue(CIVector(x: 0.5, y: 0.5), forKey: "inputPoint2")
                filter.setValue(CIVector(x: 0.75, y: 0.7), forKey: "inputPoint3")
                filter.setValue(CIVector(x: 1, y: 1), forKey: "inputPoint4")
                
                if let output = filter.outputImage {
                    return self.convertToUIImage(output)
                }
            }
            
            return nil
        }.value
    }
    
    // MARK: - Helper Methods
    
    private func convertToUIImage(_ ciImage: CIImage) -> UIImage? {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
