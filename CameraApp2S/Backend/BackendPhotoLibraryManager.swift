//
//  PhotoLibraryManager.swift
//  Microscope Viewer Camera
//
//  Created by Nimalan Arulvelan on 3/15/26.
//

import Photos
import UIKit
import SwiftUI
import Combine

/// Manages photo library access and in-app camera roll
@MainActor
class PhotoLibraryManager: ObservableObject {
    static let shared = PhotoLibraryManager()
    
    @Published var isAuthorized = false
    @Published var photos: [CapturedPhoto] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var allPhotos: PHFetchResult<PHAsset>?
    
    private init() {}
    
    // MARK: - Authorization
    
    func checkAuthorization() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            isAuthorized = true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            isAuthorized = (newStatus == .authorized || newStatus == .limited)
        default:
            isAuthorized = false
        }
    }
    
    // MARK: - Save Image
    
    func saveImage(_ image: UIImage) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                request.creationDate = Date()
            }
            
            // Reload photos after saving
            await loadPhotos()
        } catch {
            errorMessage = "Failed to save photo: \(error.localizedDescription)"
        }
    }
    
    /// Save the original photo data (JPEG/HEIC) preserving full resolution and metadata.
    func saveImageData(_ data: Data, fileExtension: String) async {
        // Write the raw data to a temp file first, then add it as a resource so
        // the original encoding and quality survive the import.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        
        do {
            try data.write(to: tempURL)
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                request.addResource(with: .photo, fileURL: tempURL, options: options)
                request.creationDate = Date()
            }
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            errorMessage = "Failed to save photo: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Save Video
    
    func saveVideo(at url: URL) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
            
            // Reload media after saving
            await loadPhotos()
        } catch {
            errorMessage = "Failed to save video: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Load Photos
    
    func loadPhotos() async {
        guard isAuthorized else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 100 // Load most recent 100 photos
        
        // Fetch both images and videos
        allPhotos = PHAsset.fetchAssets(with: fetchOptions)
        
        guard let allPhotos = allPhotos else { return }
        
        var loadedPhotos: [CapturedPhoto] = []
        
        for index in 0..<allPhotos.count {
            let asset = allPhotos.object(at: index)
            loadedPhotos.append(CapturedPhoto(asset: asset))
        }
        
        photos = loadedPhotos
    }
    
    // MARK: - Load Image
    
    func loadImage(for photo: CapturedPhoto, targetSize: CGSize = CGSize(width: 500, height: 500)) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            PHImageManager.default().requestImage(
                for: photo.asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                // Accept degraded if it's the only result, or wait for final
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let error = info?[PHImageErrorKey] as? Error
                
                if !isDegraded || error != nil || isCancelled {
                    // Final callback (or error/cancel) — always resume
                    hasResumed = true
                    continuation.resume(returning: image)
                }
                // Skip degraded — wait for the high-quality version
            }
        }
    }
    
    func loadFullResolutionImage(for photo: CapturedPhoto) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            PHImageManager.default().requestImage(
                for: photo.asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: image)
            }
        }
    }
    
    // MARK: - Latest Photo Thumbnail
    
    func loadLatestPhotoThumbnail(targetSize: CGSize = CGSize(width: 100, height: 100)) async -> UIImage? {
        guard isAuthorized else { return nil }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        let result = PHAsset.fetchAssets(with: fetchOptions)
        guard let asset = result.firstObject else { return nil }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !hasResumed, !isDegraded else { return }
                hasResumed = true
                continuation.resume(returning: image)
            }
        }
    }
    
    // MARK: - Load Video
    
    func loadVideoURL(for photo: CapturedPhoto) async -> URL? {
        guard photo.isVideo else { return nil }
        
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            PHImageManager.default().requestAVAsset(forVideo: photo.asset, options: options) { avAsset, _, _ in
                guard !hasResumed else { return }
                hasResumed = true
                if let urlAsset = avAsset as? AVURLAsset {
                    continuation.resume(returning: urlAsset.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Delete Photo
    
    func deletePhoto(_ photo: CapturedPhoto) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([photo.asset] as NSArray)
            }
            
            // Remove from local array
            photos.removeAll { $0.id == photo.id }
        } catch {
            errorMessage = "Failed to delete photo: \(error.localizedDescription)"
        }
    }
}

// MARK: - CapturedPhoto Model

struct CapturedPhoto: Identifiable, Hashable {
    let id: String
    let asset: PHAsset
    let creationDate: Date?
    let isVideo: Bool
    let videoDuration: TimeInterval
    
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.creationDate = asset.creationDate
        self.isVideo = asset.mediaType == .video
        self.videoDuration = asset.duration
    }
    
    static func == (lhs: CapturedPhoto, rhs: CapturedPhoto) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Format duration as mm:ss
    var formattedDuration: String {
        let minutes = Int(videoDuration) / 60
        let seconds = Int(videoDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
