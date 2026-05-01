//
//  ImageDetailView.swift
//  CameraApp2S
//
//  Created by Nimalan Arulvelan on 3/15/26.
//

import SwiftUI
import Photos
import AVKit

/// Full-screen image viewer with swipe navigation and thumbnail strip, similar to native Photos app
struct ImageDetailView: View {
    let photos: [CapturedPhoto]
    let initialPhoto: CapturedPhoto
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var showingDeleteAlert = false
    @State private var showingEnhancementOptions = false
    @State private var enhancedImage: UIImage?
    @State private var isEnhancing = false
    @State private var showingSaveConfirmation = false
    
    init(photos: [CapturedPhoto], initialPhoto: CapturedPhoto) {
        self.photos = photos
        self.initialPhoto = initialPhoto
        let index = photos.firstIndex(where: { $0.id == initialPhoto.id }) ?? 0
        self._currentIndex = State(initialValue: index)
    }
    
    private var currentPhoto: CapturedPhoto? {
        guard currentIndex >= 0, currentIndex < photos.count else { return nil }
        return photos[currentIndex]
    }
    
    private var currentPhotoID: String {
        currentPhoto?.id ?? ""
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Main swipeable image area
                    TabView(selection: $currentIndex) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            SingleImagePage(photo: photo, enhancedImage: index == currentIndex ? enhancedImage : nil)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: currentIndex) { _, _ in
                        // Clear enhancement when swiping to a different photo
                        enhancedImage = nil
                    }
                    
                    // Thumbnail strip at bottom
                    ThumbnailStripView(
                        photos: photos,
                        currentIndex: $currentIndex
                    )
                    .padding(.bottom, 8)
                }
                
                // Save confirmation
                if showingSaveConfirmation {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("Saved")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .transition(.opacity)
                }
                
                // Enhancement indicator
                if isEnhancing {
                    VStack {
                        Spacer()
                        HStack {
                            ProgressView()
                                .tint(.white)
                            Text("Enhancing...")
                                .foregroundStyle(.white)
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 140)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        // Enhancement options only for photos
                        if currentPhoto?.isVideo != true {
                            Button {
                                showingEnhancementOptions = true
                            } label: {
                                Label("Enhance Image", systemImage: "wand.and.stars")
                            }
                            
                            Button {
                                autoEnhance()
                            } label: {
                                Label("Auto Enhance", systemImage: "sparkles")
                            }
                            
                            if enhancedImage != nil {
                                Button {
                                    saveEnhancedImage()
                                } label: {
                                    Label("Save Enhanced Copy", systemImage: "square.and.arrow.down")
                                }
                                
                                Button {
                                    enhancedImage = nil
                                } label: {
                                    Label("Reset to Original", systemImage: "arrow.counterclockwise")
                                }
                            }
                            
                            Divider()
                        }
                        
                        Button {
                            shareCurrentImage()
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel(currentPhoto?.isVideo == true ? "Video options" : "Image options")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingEnhancementOptions) {
                if let photo = currentPhoto {
                    EnhancementOptionsSheet(photo: photo) { enhanced in
                        enhancedImage = enhanced
                    }
                }
            }
            .alert(currentPhoto?.isVideo == true ? "Delete Video" : "Delete Photo", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        if let photo = currentPhoto {
                            await PhotoLibraryManager.shared.deletePhoto(photo)
                            if PhotoLibraryManager.shared.errorMessage == nil {
                                // If no more photos, dismiss
                                if PhotoLibraryManager.shared.photos.isEmpty {
                                    dismiss()
                                }
                            }
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this \(currentPhoto?.isVideo == true ? "video" : "photo")?")
            }
            .alert("Error", isPresented: Binding(
                get: { PhotoLibraryManager.shared.errorMessage != nil },
                set: { if !$0 { PhotoLibraryManager.shared.errorMessage = nil } }
            )) {
                Button("OK") { PhotoLibraryManager.shared.errorMessage = nil }
            } message: {
                Text(PhotoLibraryManager.shared.errorMessage ?? "")
            }
        }
    }
    
    private func saveEnhancedImage() {
        guard let enhanced = enhancedImage else { return }
        
        Task {
            await PhotoLibraryManager.shared.saveImage(enhanced)
            if PhotoLibraryManager.shared.errorMessage == nil {
                showingSaveConfirmation = true
                try? await Task.sleep(for: .seconds(1.5))
                showingSaveConfirmation = false
            }
        }
    }
    
    private func autoEnhance() {
        guard let photo = currentPhoto else { return }
        
        isEnhancing = true
        
        Task {
            if let fullImage = await PhotoLibraryManager.shared.loadFullResolutionImage(for: photo) {
                enhancedImage = await ImageEnhancementManager.shared.enhanceForMicroscopy(fullImage)
            }
            isEnhancing = false
        }
    }
    
    private func shareCurrentImage() {
        guard let photo = currentPhoto else { return }
        
        Task {
            let image: UIImage?
            if let enhanced = enhancedImage {
                image = enhanced
            } else {
                image = await PhotoLibraryManager.shared.loadFullResolutionImage(for: photo)
            }
            
            guard let image else { return }
            
            let activityController = UIActivityViewController(
                activityItems: [image],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                activityController.popoverPresentationController?.sourceView = rootViewController.view
                rootViewController.present(activityController, animated: true)
            }
        }
    }
}

// MARK: - Single Media Page (used inside TabView)

private struct SingleImagePage: View {
    let photo: CapturedPhoto
    let enhancedImage: UIImage?
    @State private var fullResImage: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var videoPlayer: AVPlayer?
    
    var body: some View {
        Group {
            if photo.isVideo {
                if let player = videoPlayer {
                    VideoPlayer(player: player)
                        .accessibilityLabel("Microscope video")
                        .accessibilityHint("Video playback with controls")
                        .onDisappear {
                            player.pause()
                        }
                } else {
                    ProgressView()
                        .tint(.white)
                }
            } else if let displayImage = enhancedImage ?? fullResImage {
                ImageViewer(image: displayImage, scale: $scale)
                    .accessibilityLabel(enhancedImage != nil ? "Enhanced microscope image" : "Microscope image")
                    .accessibilityHint("Double tap to zoom, swipe to navigate")
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task {
            if photo.isVideo {
                if let url = await PhotoLibraryManager.shared.loadVideoURL(for: photo) {
                    videoPlayer = AVPlayer(url: url)
                }
            } else {
                fullResImage = await PhotoLibraryManager.shared.loadFullResolutionImage(for: photo)
            }
        }
    }
}

// MARK: - Enhancement Options Sheet Helper

private struct EnhancementOptionsSheet: View {
    let photo: CapturedPhoto
    let onEnhanced: (UIImage?) -> Void
    @State private var originalImage: UIImage?
    
    var body: some View {
        Group {
            if let originalImage {
                EnhancementOptionsView(
                    originalImage: originalImage,
                    onEnhanced: onEnhanced
                )
            } else {
                ProgressView("Loading image...")
            }
        }
        .task {
            originalImage = await PhotoLibraryManager.shared.loadFullResolutionImage(for: photo)
        }
    }
}

// MARK: - Thumbnail Strip

private struct ThumbnailStripView: View {
    let photos: [CapturedPhoto]
    @Binding var currentIndex: Int
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        ThumbnailItem(
                            photo: photo,
                            isSelected: index == currentIndex
                        )
                        .id(index)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentIndex = index
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 70)
            .background(.black.opacity(0.6))
            .onChange(of: currentIndex) { _, newIndex in
                withAnimation {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(currentIndex, anchor: .center)
            }
        }
    }
}

// MARK: - Single Thumbnail in Strip

private struct ThumbnailItem: View {
    let photo: CapturedPhoto
    let isSelected: Bool
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: 56, height: 56)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? .white : .clear, lineWidth: 2)
        )
        .opacity(isSelected ? 1.0 : 0.6)
        .accessibilityLabel("Thumbnail")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .task {
            image = await PhotoLibraryManager.shared.loadImage(
                for: photo,
                targetSize: CGSize(width: 120, height: 120)
            )
        }
    }
}

// MARK: - Image Viewer with Zoom

struct ImageViewer: View {
    let image: UIImage
    @Binding var scale: CGFloat
    @State private var steadyScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            let imageSize = imageFitSize(in: geometry.size)
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(pinchGesture(imageSize: imageSize, viewSize: geometry.size))
                .simultaneousGesture(dragGesture(imageSize: imageSize, viewSize: geometry.size))
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if scale > 1.0 {
                            scale = 1.0
                            steadyScale = 1.0
                            offset = .zero
                            steadyOffset = .zero
                        } else {
                            scale = 2.5
                            steadyScale = 2.5
                        }
                    }
                }
        }
    }
    
    // MARK: - Gestures
    
    private func pinchGesture(imageSize: CGSize, viewSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = steadyScale * value
                scale = min(max(newScale, 0.5), 10.0)
            }
            .onEnded { value in
                var finalScale = steadyScale * value
                
                if finalScale < 1.0 {
                    finalScale = 1.0
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = .zero
                        steadyOffset = .zero
                    }
                } else if finalScale > 10.0 {
                    finalScale = 10.0
                }
                
                withAnimation(.easeOut(duration: 0.2)) {
                    scale = finalScale
                }
                steadyScale = finalScale
                
                // Clamp offset after zoom change
                let clamped = clampedOffset(offset, scale: finalScale, imageSize: imageSize, viewSize: viewSize)
                if clamped != offset {
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = clamped
                    }
                    steadyOffset = clamped
                }
            }
    }
    
    private func dragGesture(imageSize: CGSize, viewSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.0 else { return }
                offset = CGSize(
                    width: steadyOffset.width + value.translation.width,
                    height: steadyOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                guard scale > 1.0 else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = .zero
                    }
                    steadyOffset = .zero
                    return
                }
                
                let proposed = CGSize(
                    width: steadyOffset.width + value.translation.width,
                    height: steadyOffset.height + value.translation.height
                )
                let clamped = clampedOffset(proposed, scale: scale, imageSize: imageSize, viewSize: viewSize)
                withAnimation(.easeOut(duration: 0.2)) {
                    offset = clamped
                }
                steadyOffset = clamped
            }
    }
    
    // MARK: - Layout Helpers
    
    /// Calculate the size the image occupies when fitted inside the view
    private func imageFitSize(in viewSize: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let viewAspect = viewSize.width / viewSize.height
        
        if imageAspect > viewAspect {
            let width = viewSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            let height = viewSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }
    
    /// Clamp offset so the image edges don't pull away from the view edges
    private func clampedOffset(_ proposed: CGSize, scale: CGFloat, imageSize: CGSize, viewSize: CGSize) -> CGSize {
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        
        let maxX = max((scaledWidth - viewSize.width) / 2, 0)
        let maxY = max((scaledHeight - viewSize.height) / 2, 0)
        
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }
}

#Preview {
    ImageDetailView(
        photos: [CapturedPhoto(asset: .init())],
        initialPhoto: CapturedPhoto(asset: .init())
    )
}
