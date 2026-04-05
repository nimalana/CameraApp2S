//
//  ImageDetailView.swift
//  CameraApp2S
//
//  Created by Nimalan Arulvelan on 3/15/26.
//

import SwiftUI
import Photos

/// Detailed view for examining and enhancing microscope images
struct ImageDetailView: View {
    let photo: CapturedPhoto
    @Environment(\.dismiss) private var dismiss
    @State private var fullResImage: UIImage?
    @State private var enhancedImage: UIImage?
    @State private var isEnhancing = false
    @State private var showingEnhancementOptions = false
    @State private var currentScale: CGFloat = 1.0
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let displayImage = enhancedImage ?? fullResImage {
                    ImageViewer(image: displayImage, scale: $currentScale)
                } else {
                    ProgressView("Loading image...")
                        .foregroundStyle(.white)
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
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Image Detail")
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
                                enhancedImage = nil
                            } label: {
                                Label("Reset to Original", systemImage: "arrow.counterclockwise")
                            }
                        }
                        
                        Divider()
                        
                        if let imageToShare = enhancedImage ?? fullResImage {
                            Button {
                                shareImage(imageToShare)
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
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
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingEnhancementOptions) {
                EnhancementOptionsView(
                    originalImage: fullResImage,
                    onEnhanced: { enhanced in
                        enhancedImage = enhanced
                    }
                )
            }
            .alert("Delete Photo", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await PhotoLibraryManager.shared.deletePhoto(photo)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this photo?")
            }
        }
        .task {
            fullResImage = await PhotoLibraryManager.shared.loadFullResolutionImage(for: photo)
        }
    }
    
    private func autoEnhance() {
        guard let image = fullResImage else { return }
        
        isEnhancing = true
        
        Task {
            enhancedImage = await ImageEnhancementManager.shared.enhanceForMicroscopy(image)
            isEnhancing = false
        }
    }
    
    private func shareImage(_ image: UIImage) {
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
    ImageDetailView(photo: CapturedPhoto(asset: .init()))
}
