//
//  PhotoLibraryManager.swift
//  CameraApp2S
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
    
    // MARK: - Load Photos
    
    func loadPhotos() async {
        guard isAuthorized else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 100 // Load most recent 100 photos
        
        allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
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
        options.deliveryMode = .highQualityFormat
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
                // Guard against multiple callbacks (degraded + final)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !hasResumed, !isDegraded else { return }
                hasResumed = true
                continuation.resume(returning: image)
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
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !hasResumed, !isDegraded else { return }
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
        
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
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

struct CapturedPhoto: Identifiable {
    let id: String
    let asset: PHAsset
    let creationDate: Date?
    
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.creationDate = asset.creationDate
    }
}
