# Privacy Configuration for CameraApp2S

## Required Info.plist Keys

Add the following keys to your Info.plist file:

### Camera Access
```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access to capture microscope images with enhanced quality and focus control.</string>
```

### Photo Library Access
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to your photo library to save and view microscope images.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app needs permission to save captured microscope images to your photo library.</string>
```

## How to Add These Keys in Xcode

1. Open your project in Xcode
2. Select your app target
3. Go to the "Info" tab
4. Click the "+" button to add a new key
5. Search for and add each of the keys above
6. Enter the corresponding description text

## Alternative: Edit Info.plist Directly

If you have an Info.plist file in your project, you can add the keys directly:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSCameraUsageDescription</key>
    <string>This app requires camera access to capture microscope images with enhanced quality and focus control.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>This app needs access to your photo library to save and view microscope images.</string>
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>This app needs permission to save captured microscope images to your photo library.</string>
</dict>
</plist>
```

## Additional Recommendations

### Enable Background Modes (Optional)
If you want to support background photo processing:

1. Go to your target's "Signing & Capabilities" tab
2. Click "+" to add capability
3. Add "Background Modes"
4. Check "Background processing"

### Camera Quality Settings
The app is configured for maximum photo quality suitable for microscope imaging. No additional settings needed.
