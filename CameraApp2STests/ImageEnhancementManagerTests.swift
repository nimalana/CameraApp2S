//
//  ImageEnhancementManagerTests.swift
//  CameraApp2STests
//
//  Created by Nimalan Arulvelan on 4/5/26.
//

import Testing
import UIKit
@testable import CameraApp2S

struct ImageEnhancementManagerTests {
    
    let manager = ImageEnhancementManager.shared
    
    /// Creates a solid-color test image
    private func makeTestImage(width: Int = 100, height: Int = 100, color: UIColor = .red) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
    
    // MARK: - Enhancement Options Defaults
    
    @Test func enhancementOptionsHaveCorrectDefaults() {
        let options = ImageEnhancementManager.EnhancementOptions()
        #expect(options.brightness == 0.0)
        #expect(options.contrast == 1.0)
        #expect(options.saturation == 1.0)
        #expect(options.sharpness == 0.0)
        #expect(options.enableNoiseReduction == true)
        #expect(options.enableEdgeEnhancement == false)
    }
    
    // MARK: - Auto Enhancement
    
    @Test func autoEnhanceReturnsImage() async {
        let input = makeTestImage()
        let result = await manager.autoEnhance(input)
        #expect(result != nil)
    }
    
    @Test func autoEnhancePreservesDimensions() async {
        let input = makeTestImage(width: 200, height: 150)
        let result = await manager.autoEnhance(input)
        #expect(result != nil)
        #expect(result!.size.width == 200)
        #expect(result!.size.height == 150)
    }
    
    // MARK: - Manual Enhancement
    
    @Test func manualEnhanceWithDefaultOptionsReturnsImage() async {
        let input = makeTestImage()
        let options = ImageEnhancementManager.EnhancementOptions()
        let result = await manager.enhance(input, options: options)
        #expect(result != nil)
    }
    
    @Test func manualEnhanceWithBrightnessReturnsImage() async {
        let input = makeTestImage()
        let options = ImageEnhancementManager.EnhancementOptions(brightness: 0.5)
        let result = await manager.enhance(input, options: options)
        #expect(result != nil)
    }
    
    @Test func manualEnhanceWithSharpnessReturnsImage() async {
        let input = makeTestImage()
        let options = ImageEnhancementManager.EnhancementOptions(sharpness: 1.5)
        let result = await manager.enhance(input, options: options)
        #expect(result != nil)
    }
    
    @Test func manualEnhanceWithEdgeEnhancementReturnsImage() async {
        let input = makeTestImage()
        let options = ImageEnhancementManager.EnhancementOptions(
            enableNoiseReduction: false,
            enableEdgeEnhancement: true
        )
        let result = await manager.enhance(input, options: options)
        #expect(result != nil)
    }
    
    @Test func manualEnhanceWithAllOptionsReturnsImage() async {
        let input = makeTestImage()
        let options = ImageEnhancementManager.EnhancementOptions(
            brightness: 0.1,
            contrast: 1.3,
            saturation: 1.2,
            sharpness: 0.8,
            enableNoiseReduction: true,
            enableEdgeEnhancement: true
        )
        let result = await manager.enhance(input, options: options)
        #expect(result != nil)
    }
    
    // MARK: - Microscopy Enhancement
    
    @Test func enhanceForMicroscopyReturnsImage() async {
        let input = makeTestImage()
        let result = await manager.enhanceForMicroscopy(input)
        #expect(result != nil)
    }
    
    @Test func enhanceForMicroscopyPreservesDimensions() async {
        let input = makeTestImage(width: 300, height: 400)
        let result = await manager.enhanceForMicroscopy(input)
        #expect(result != nil)
        #expect(result!.size.width == 300)
        #expect(result!.size.height == 400)
    }
    
    // MARK: - Histogram Equalization
    
    @Test func histogramEqualizationReturnsImage() async {
        let input = makeTestImage()
        let result = await manager.equalizeHistogram(input)
        #expect(result != nil)
    }
    
    // MARK: - Edge Cases
    
    @Test func enhanceTinyImageReturnsImage() async {
        let input = makeTestImage(width: 1, height: 1)
        let result = await manager.autoEnhance(input)
        #expect(result != nil)
    }
    
    @Test func enhanceLargeImageReturnsImage() async {
        let input = makeTestImage(width: 2000, height: 2000)
        let options = ImageEnhancementManager.EnhancementOptions()
        let result = await manager.enhance(input, options: options)
        #expect(result != nil)
    }
}
