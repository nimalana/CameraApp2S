//
//  GalleryView.swift
//  CameraApp2S
//
//  Created by Nimalan Arulvelan on 3/15/26.
//

import SwiftUI
import Combine

/// In-app camera roll for viewing captured microscope images
struct GalleryView: View {
    @StateObject private var photoLibrary = PhotoLibraryManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: CapturedPhoto?
    @State private var showingImageDetail = false
    
    let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 2)
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if photoLibrary.isLoading {
                    ProgressView("Loading photos...")
                } else if photoLibrary.photos.isEmpty {
                    ContentUnavailableView(
                        "No Photos",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Capture your first microscope image")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(photoLibrary.photos) { photo in
                                PhotoThumbnailView(photo: photo)
                                    .aspectRatio(1, contentMode: .fill)
                                    .onTapGesture {
                                        selectedPhoto = photo
                                        showingImageDetail = true
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingImageDetail) {
                if let photo = selectedPhoto {
                    ImageDetailView(photo: photo)
                }
            }
            .task {
                await photoLibrary.checkAuthorization()
                if photoLibrary.isAuthorized {
                    await photoLibrary.loadPhotos()
                }
            }
        }
    }
}

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
    let photo: CapturedPhoto
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task {
            image = await PhotoLibraryManager.shared.loadImage(
                for: photo,
                targetSize: CGSize(width: 200, height: 200)
            )
        }
    }
}

#Preview {
    GalleryView()
}
