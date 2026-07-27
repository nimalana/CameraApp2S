# Privacy Configuration for Microscope Viewer Camera

## Required Info.plist Keys

Add the following keys to your Info.plist file:

### Camera Access
```xml
<key>NSCameraUsageDescription</key>
<string>Access to the camera is used to capture photos and videos through a microscope eyepiece adapter -- for example, recording a specimen on a slide so you can review it later. Captured media is stored only on your device unless you choose to share it.</string>
```

### Microphone Access
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Access to the microphone is used to record audio alongside video -- for example, narrating what you are observing through the microscope while recording. Audio is stored only in the video files you save and is never transmitted off the device.</string>
```

### Photo Library Access
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Access to your photo library is used to browse and review microscope photos and videos you have previously captured with this app -- for example, comparing today's specimen against one you recorded last week.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Permission to add to your photo library is used to save the photos and videos you capture in the app -- for example, saving a recording of a slide so you can revisit or share it later.</string>
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
    <string>Access to the camera is used to capture photos and videos through a microscope eyepiece adapter -- for example, recording a specimen on a slide so you can review it later. Captured media is stored only on your device unless you choose to share it.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Access to the microphone is used to record audio alongside video -- for example, narrating what you are observing through the microscope while recording. Audio is stored only in the video files you save and is never transmitted off the device.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Access to your photo library is used to browse and review microscope photos and videos you have previously captured with this app -- for example, comparing today's specimen against one you recorded last week.</string>
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>Permission to add to your photo library is used to save the photos and videos you capture in the app -- for example, saving a recording of a slide so you can revisit or share it later.</string>
</dict>
</plist>
```

## App Store Privacy Notes

The app's privacy manifest declares no tracking, no tracking domains, and no collected data types. If future versions add analytics, cloud sync, accounts, crash reporting, advertising, or other networked services, update `PrivacyInfo.xcprivacy`, the App Store privacy nutrition label, and the public privacy policy before release.

For France, Italy, and other EU/EEA availability, keep the public privacy policy clear that captured media remains on device unless the user chooses to share it, and avoid medical or diagnostic claims unless the app is reviewed for the applicable regulatory requirements.

## Additional Recommendations

### Enable Background Modes (Optional)
If you want to support background photo processing:

1. Go to your target's "Signing & Capabilities" tab
2. Click "+" to add capability
3. Add "Background Modes"
4. Check "Background processing"

### Camera Quality Settings
The app is configured for maximum photo quality suitable for microscope imaging. No additional settings needed.
