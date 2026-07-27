# Project Structure

```
Microscope Viewer Camera/
├── Backend/                          # Business Logic Layer
│   ├── CameraManager.swift           # Camera control & AVFoundation
│   ├── PhotoLibraryManager.swift     # Photo library integration
│   └── ImageEnhancementManager.swift # Image processing & filters
│
├── Frontend/                         # User Interface Layer
│   ├── CameraView.swift              # Main camera screen
│   ├── CameraPreviewView.swift       # Live camera preview
│   ├── CameraSettingsView.swift      # Settings panel
│   ├── GalleryView.swift             # Photo grid gallery
│   ├── ImageDetailView.swift         # Full-screen image viewer
│   └── EnhancementOptionsView.swift  # Manual enhancement controls
│
├── ContentView.swift                 # Root view (launches CameraView)
├── CameraApp2SApp.swift             # App entry point
│
├── README.md                         # Full documentation
└── PRIVACY_SETUP.md                  # Info.plist configuration guide
```

## Component Relationships

```
MicroscopeViewerCameraApp
    └── ContentView
            └── CameraView
                    ├── CameraPreviewView (uses CameraManager)
                    ├── CameraSettingsView (uses CameraManager)
                    └── GalleryView
                            └── ImageDetailView
                                    └── EnhancementOptionsView
```

## Data Flow

```
User Action → Frontend View → Backend Manager → AVFoundation/Photos/CoreImage
                    ↓                 ↓
            UI Update ← Published Properties
```

## Key Classes

### Backend
- `CameraManager` (ObservableObject): Main actor, publishes camera state
- `PhotoLibraryManager` (ObservableObject, Singleton): Manages photo library
- `ImageEnhancementManager` (Singleton): Pure processing, no state

### Frontend
- All SwiftUI Views
- Use @StateObject or @ObservedObject for managers
- Use @State for local UI state

## Dependencies

- Backend has NO dependencies on Frontend
- Frontend depends on Backend for data/operations
- Clean separation allows for easy testing and maintenance
