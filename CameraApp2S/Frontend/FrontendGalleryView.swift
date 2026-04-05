//
//  GalleryView.swift
//  CameraApp2S
//
//  Created by Nimalan Arulvelan on 3/15/26.
//

import SwiftUI

/// In-app camera roll for viewing captured microscope images
struct GalleryView: View {
    @StateObject private var photoLibrary = PhotoLibraryManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: CapturedPhoto?
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1.5), count: 3)
    
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
                        LazyVGrid(columns: columns, spacing: 1.5) {
                            ForEach(photoLibrary.photos) { photo in
                                PhotoThumbnailView(photo: photo)
                                    .onTapGesture {
                                        selectedPhoto = photo
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
            .sheet(item: $selectedPhoto) { photo in
                ImageDetailView(photo: photo)
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
        GeometryReader { geometry in
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            image = await PhotoLibraryManager.shared.loadImage(
                for: photo,
                targetSize: CGSize(width: 300, height: 300)
            )
        }
    }
}

#Preview {
    GalleryView()
}
