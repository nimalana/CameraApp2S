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
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale *= delta
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            
                            // Reset if zoomed out too far
                            if scale < 1.0 {
                                withAnimation {
                                    scale = 1.0
                                    offset = .zero
                                }
                            }
                            
                            // Limit maximum zoom
                            if scale > 10.0 {
                                scale = 10.0
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if scale > 1.0 {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.0
                        }
                    }
                }
        }
    }
}

#Preview {
    ImageDetailView(photo: CapturedPhoto(asset: .init()))
}
