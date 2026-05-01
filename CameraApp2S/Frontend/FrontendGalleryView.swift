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
                        "No Photos or Videos",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Capture your first microscope image or video")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 1.5) {
                            ForEach(photoLibrary.photos) { photo in
                                PhotoThumbnailView(photo: photo)
                                    .onTapGesture {
                                        selectedPhoto = photo
                                    }
                                    .accessibilityLabel("\(photo.isVideo ? "Video" : "Photo") taken \(photo.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "unknown date")")
                                    .accessibilityHint(photo.isVideo ? "Opens video player" : "Opens full-size image")
                                    .accessibilityAddTraits(.isButton)
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
                ImageDetailView(photos: photoLibrary.photos, initialPhoto: photo)
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
        ZStack(alignment: .bottomLeading) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .overlay {
                        ProgressView()
                    }
            }
            
            // Video duration badge
            if photo.isVideo {
                HStack(spacing: 3) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                    Text(photo.formattedDuration)
                        .font(.caption2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 3))
                .padding(4)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
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
