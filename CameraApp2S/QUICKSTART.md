# Quick Start Guide

## Initial Setup (Required!)

### Step 1: Add Privacy Permissions
The app will crash without these! Add to your Info.plist:

**In Xcode:**
1. Click on your project in the navigator
2. Select your app target
3. Go to "Info" tab
4. Click "+" to add keys:
   - **Privacy - Camera Usage Description**: "This app requires camera access to capture microscope images with enhanced quality and focus control."
   - **Privacy - Photo Library Usage Description**: "This app needs access to your photo library to save and view microscope images."
   - **Privacy - Photo Library Additions Usage Description**: "This app needs permission to save captured microscope images to your photo library."

OR copy the contents from `Info-Privacy-Keys.plist` into your Info.plist file.

### Step 2: Build and Run
1. Select a physical iOS device (camera won't work in Simulator)
2. Build and run (Cmd+R)
3. Grant camera and photo library permissions when prompted

## Feature Overview

### Main Camera Screen
- **Live Preview**: See what the camera sees in real-time
- **Tap to Focus**: Tap anywhere to focus on that spot
- **Zoom Slider**: Drag to zoom in/out (1x to 10x)
- **Lock Button** (left): Lock/unlock focus and exposure
- **Capture Button** (center): Take a photo
- **Focus Mode** (right): Toggle auto/manual focus
- **Gallery** (top-left): View captured photos
- **Settings** (top-right): Camera configuration

### Gallery
- **Grid View**: All your captured images
- **Tap Image**: View full screen
- **Pinch to Zoom**: Up to 10x magnification
- **Pan**: Move around zoomed image
- **Menu**: Enhance, share, or delete

### Image Enhancement
- **Auto Enhance**: Quick one-tap improvement
- **Manual Controls**: Fine-tune with sliders
- **Microscope Preset**: Optimized for microscopy
- **High Contrast**: For better visibility

## Common Tasks

### Taking a High-Quality Microscope Photo
```
1. Position your smartphone on the microscope
2. Adjust zoom until specimen fills frame
3. Tap on the specimen to focus
4. Press LOCK button to prevent refocusing
5. Press white CAPTURE button
6. Image automatically saves to gallery
```

### Enhancing a Photo
```
1. Tap Gallery icon (top-left)
2. Select your image
3. Tap ⋯ menu (top-right)
4. Choose "Auto Enhance" or "Enhance Image"
5. Adjust settings as needed
6. Tap "Apply"
```

### Sharing an Image
```
1. Open image in Gallery
2. Tap ⋯ menu
3. Tap the Share icon
4. Choose destination (Messages, Mail, etc.)
```

### Changing Focus Mode
```
Continuous Auto: Camera constantly adjusts focus
Auto Focus: Focus once when you tap
Manual: Tap to set focus, then stays until next tap
Locked: No focus changes allowed
```

## Tips for Best Results

### Lighting
- Ensure specimen is well-lit
- Adjust microscope light if available
- Avoid shadows on the lens

### Stability
- Use a stable mount or tripod
- Hold device steady while capturing
- Use the lock feature to prevent drift

### Focus
- Use maximum zoom for detail
- Lock focus once properly focused
- Clean camera lens before use

### Enhancement
- Capture first, enhance later
- Try auto enhance before manual
- Use microscope preset for biological samples
- Increase sharpness to see fine details

## Troubleshooting

| Problem | Solution |
|---------|----------|
| App crashes on launch | Add privacy permissions to Info.plist |
| Camera shows black screen | Check camera permissions in Settings |
| Photos not saving | Grant photo library permissions |
| Can't focus | Tap on subject, try locking focus |
| Image too dark | Adjust brightness in enhancement |
| Image blurry | Ensure stable mount, lock focus, increase sharpness |

## Keyboard Shortcuts (none - touch only)
This is a touch-based app designed for use with physical iOS devices.

## Minimum Requirements
- iOS 17.0+
- Physical device with camera
- Photo library access
- 50MB free storage (recommended)

## First Time Use Checklist
- [ ] Added privacy keys to Info.plist
- [ ] Built app on physical device
- [ ] Granted camera permission
- [ ] Granted photo library permission
- [ ] Took test photo
- [ ] Verified photo appears in gallery
- [ ] Tried zoom feature
- [ ] Tried focus lock
- [ ] Tried image enhancement

## Support
For issues, check:
1. README.md - Full documentation
2. PRIVACY_SETUP.md - Permission setup
3. PROJECT_STRUCTURE.md - Code organization
