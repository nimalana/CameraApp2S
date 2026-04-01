# Microscope Camera App - Documentation

## Overview
A professional camera application designed for smartphone-based microscope systems with advanced features including camera locking, enhanced image quality, auto/manual focusing, and an in-app camera roll.

## Architecture

The app is organized into two main directories:

### Backend (`Backend/`)
Contains all business logic, camera management, and data handling:

- **CameraManager.swift**: Core camera functionality
  - AVFoundation session management
  - Focus control (auto/manual/locked)
  - Exposure control
  - Zoom management (up to 10x)
  - High-quality photo capture
  - Camera locking for stable microscope imaging

- **PhotoLibraryManager.swift**: Photo library integration
  - Photo library authorization
  - Save captured images
  - Load photos for gallery
  - Delete photos
  - Thumbnail generation

- **ImageEnhancementManager.swift**: Image processing
  - Auto enhancement
  - Manual adjustments (brightness, contrast, saturation, sharpness)
  - Noise reduction
  - Edge enhancement
  - Histogram equalization
  - Microscope-specific presets

### Frontend (`Frontend/`)
Contains all UI components:

- **CameraView.swift**: Main camera interface
  - Live camera preview
  - Capture button
  - Focus lock/unlock toggle
  - Zoom slider
  - Access to settings and gallery

- **CameraPreviewView.swift**: Camera preview layer
  - Live video feed
  - Tap-to-focus with visual indicator
  - Gesture handling

- **CameraSettingsView.swift**: Settings panel
  - Focus mode selection
  - Camera configuration
  - App information

- **GalleryView.swift**: In-app camera roll
  - Grid layout of captured images
  - Thumbnail loading
  - Photo selection

- **ImageDetailView.swift**: Full-screen image viewer
  - Pinch-to-zoom (up to 10x)
  - Pan gestures
  - Enhancement options
  - Share functionality
  - Delete capability

- **EnhancementOptionsView.swift**: Image enhancement controls
  - Manual adjustment sliders
  - Real-time preview
  - Presets for microscopy
  - Apply/cancel actions

## Key Features

### 1. Camera Locking
- Lock focus and exposure for stable microscope imaging
- Visual indicator when locked
- Prevents auto-adjustments during observation

### 2. Enhanced Image Quality
- Maximum photo quality prioritization
- HEVC codec support for better compression
- Optimized for microscope imaging
- High-resolution capture

### 3. Focus Control
- **Continuous Auto Focus**: Automatic focus tracking
- **Auto Focus**: Single focus operation
- **Manual Focus**: Tap-to-focus anywhere on screen
- **Locked Focus**: Prevent any focus changes

### 4. Zoom
- Digital zoom up to 10x (or camera maximum)
- Smooth slider control
- Real-time zoom factor display

### 5. In-App Camera Roll
- Grid layout of captured images
- Fast thumbnail loading
- Full-resolution image viewing
- Pinch-to-zoom and pan
- Share and delete options

### 6. Image Enhancement
- **Auto Enhancement**: One-tap optimization
- **Manual Controls**:
  - Brightness adjustment
  - Contrast enhancement
  - Saturation control
  - Sharpness for detail
  - Noise reduction
  - Edge enhancement
- **Presets**:
  - Microscope preset
  - High contrast preset
  - Custom adjustments

## Setup Instructions

### 1. Privacy Permissions
Add the following keys to your Info.plist:

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access to capture microscope images with enhanced quality and focus control.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to your photo library to save and view microscope images.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app needs permission to save captured microscope images to your photo library.</string>
```

### 2. Build Requirements
- iOS 17.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

### 3. Frameworks Used
- SwiftUI (UI framework)
- AVFoundation (Camera management)
- Photos (Photo library)
- CoreImage (Image processing)
- UIKit (Camera preview)

## Usage Guide

### Capturing Images
1. Launch the app to see the live camera preview
2. Adjust zoom using the slider at the bottom
3. Tap anywhere on screen to focus on that point
4. Tap the lock button to lock focus and exposure
5. Press the white capture button to take a photo

### Viewing Gallery
1. Tap the gallery icon (photo stack) in top-left
2. Browse your captured microscope images
3. Tap any image to view in full screen
4. Pinch to zoom, drag to pan
5. Use the menu to enhance, share, or delete

### Enhancing Images
1. Open an image in detail view
2. Tap the menu (⋯) button
3. Select "Auto Enhance" for quick improvement
4. Or select "Enhance Image" for manual controls
5. Adjust sliders to your preference
6. Apply presets for common scenarios
7. Tap "Apply" to save changes

### Camera Settings
1. Tap the gear icon in top-right
2. Choose focus mode
3. View current zoom level
4. Configure camera options

## Technical Details

### Camera Configuration
- Session preset: `.photo` (highest quality)
- Camera preference: Dual/Telephoto/Wide-angle (in order)
- Focus modes: Continuous auto, auto, locked
- Exposure modes: Continuous auto, auto, locked
- Maximum zoom: Limited to 10x for stability

### Image Processing
- CoreImage filters for enhancement
- Async processing to maintain UI responsiveness
- High-quality format prioritization
- Noise reduction optimized for microscopy

### Performance Optimizations
- Async/await for smooth operations
- Background queue for camera operations
- Lazy loading of thumbnails
- Image caching for gallery

## Best Practices for Microscope Use

1. **Stabilize Your Setup**: Use a stable mount for your smartphone
2. **Lock Focus**: Always lock focus once you've found your subject
3. **Use Maximum Zoom**: Zoom in as much as needed for detail
4. **Adjust Lighting**: Ensure proper illumination of your specimen
5. **Enhance Later**: Capture first, enhance in the gallery for best results
6. **Save Regularly**: Photos are automatically saved to your library

## Troubleshooting

### Camera Won't Start
- Check camera permissions in Settings > Privacy > Camera
- Restart the app
- Ensure no other app is using the camera

### Photos Not Saving
- Check photo library permissions in Settings > Privacy > Photos
- Ensure sufficient storage space
- Grant full photo library access

### Focus Issues
- Clean your camera lens
- Ensure adequate lighting
- Try manual focus (tap on subject)
- Use lock to prevent refocusing

## Future Enhancements
- Time-lapse capture
- Video recording
- Measurement tools
- Annotation support
- Cloud sync
- Multiple microscope profiles

## Credits
Created for smartphone-based microscope systems
Optimized for scientific and educational use
