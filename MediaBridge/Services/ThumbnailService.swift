import Foundation
import UIKit
import Photos

class ThumbnailService {
    static let shared = ThumbnailService()

    private let imageManager = PHCachingImageManager()
    private let cache = NSCache<NSString, NSData>()
    private let queue = DispatchQueue(label: "com.mediabridge.thumbnails", qos: .userInitiated)

    // Thumbnail settings
    private let thumbnailSize = CGSize(width: 200, height: 200)
    private let jpegQuality: CGFloat = 0.7

    private init() {
        // Configure cache limits
        cache.countLimit = 500  // Max 500 thumbnails in memory
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB max
    }

    // MARK: - Thumbnail Generation

    func getThumbnail(for assetId: String, completion: @escaping (Data?) -> Void) {
        // Check cache first
        if let cached = cache.object(forKey: assetId as NSString) {
            completion(cached as Data)
            return
        }

        // Generate thumbnail
        guard let phAsset = PhotoLibraryService.shared.getPHAsset(for: assetId) else {
            completion(nil)
            return
        }

        generateThumbnail(for: phAsset) { [weak self] data in
            if let data = data {
                // Cache the result
                self?.cache.setObject(data as NSData, forKey: assetId as NSString, cost: data.count)
            }
            completion(data)
        }
    }

    private func generateThumbnail(for asset: PHAsset, completion: @escaping (Data?) -> Void) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = false

        let targetSize = calculateTargetSize(for: asset)

        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            guard let image = image else {
                // Check if it's a degraded image being delivered first
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    return  // Wait for the full quality version
                }
                completion(nil)
                return
            }

            // Convert to JPEG data
            let jpegData = image.jpegData(compressionQuality: self.jpegQuality)
            completion(jpegData)
        }
    }

    private func calculateTargetSize(for asset: PHAsset) -> CGSize {
        let scale = UIScreen.main.scale
        let aspectRatio = CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)

        var targetSize: CGSize
        if aspectRatio > 1 {
            // Landscape
            targetSize = CGSize(
                width: thumbnailSize.width * scale,
                height: (thumbnailSize.width / aspectRatio) * scale
            )
        } else {
            // Portrait
            targetSize = CGSize(
                width: (thumbnailSize.height * aspectRatio) * scale,
                height: thumbnailSize.height * scale
            )
        }

        return targetSize
    }

    // MARK: - Batch Operations

    func prefetchThumbnails(for assetIds: [String]) {
        guard let phAssets = assetIds.compactMap({ PhotoLibraryService.shared.getPHAsset(for: $0) }) as [PHAsset]?,
              !phAssets.isEmpty else {
            return
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .fastFormat

        imageManager.startCachingImages(
            for: phAssets,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: options
        )
    }

    func stopPrefetching(for assetIds: [String]) {
        guard let phAssets = assetIds.compactMap({ PhotoLibraryService.shared.getPHAsset(for: $0) }) as [PHAsset]?,
              !phAssets.isEmpty else {
            return
        }

        imageManager.stopCachingImages(
            for: phAssets,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    func stopAllPrefetching() {
        imageManager.stopCachingImagesForAllAssets()
    }

    // MARK: - Cache Management

    func clearCache() {
        cache.removeAllObjects()
        imageManager.stopCachingImagesForAllAssets()
    }

    func removeCachedThumbnail(for assetId: String) {
        cache.removeObject(forKey: assetId as NSString)
    }

    // MARK: - Batch Streaming

    /// Generate thumbnails for multiple assets and call back with each one
    func streamThumbnails(
        for assetIds: [String],
        onThumbnail: @escaping (String, Data) -> Void,
        onComplete: @escaping () -> Void
    ) {
        let group = DispatchGroup()

        for assetId in assetIds {
            group.enter()

            queue.async { [weak self] in
                self?.getThumbnail(for: assetId) { data in
                    if let data = data {
                        DispatchQueue.main.async {
                            onThumbnail(assetId, data)
                        }
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            onComplete()
        }
    }

    /// Sequential thumbnail streaming with progress callback
    func streamThumbnailsSequentially(
        for assetIds: [String],
        onThumbnail: @escaping (String, Data, Int, Int) -> Void,
        onComplete: @escaping () -> Void
    ) {
        let total = assetIds.count
        var completed = 0

        func processNext(index: Int) {
            guard index < assetIds.count else {
                DispatchQueue.main.async {
                    onComplete()
                }
                return
            }

            let assetId = assetIds[index]

            getThumbnail(for: assetId) { data in
                completed += 1

                if let data = data {
                    DispatchQueue.main.async {
                        onThumbnail(assetId, data, completed, total)
                    }
                }

                // Process next after a small delay to prevent overwhelming
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    processNext(index: index + 1)
                }
            }
        }

        queue.async {
            processNext(index: 0)
        }
    }
}
