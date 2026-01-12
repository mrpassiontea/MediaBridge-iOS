import Foundation
import Photos
import Combine

class PhotoLibraryService: ObservableObject {
    static let shared = PhotoLibraryService()

    @Published private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published private(set) var assets: [Asset] = []
    @Published private(set) var isLoading = false

    private var phAssetCache: [String: PHAsset] = [:]
    private let imageManager = PHCachingImageManager()

    private init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.authorizationStatus = status
        }
        return status == .authorized || status == .limited
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    // MARK: - Fetching Assets

    func fetchAllAssets() async {
        guard isAuthorized else {
            print("[PhotoLibrary] Not authorized")
            return
        }

        await MainActor.run {
            self.isLoading = true
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.includeHiddenAssets = false

        // Fetch images and videos
        let imageResults = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let videoResults = PHAsset.fetchAssets(with: .video, options: fetchOptions)

        var fetchedAssets: [Asset] = []
        var cache: [String: PHAsset] = [:]

        // Process images
        imageResults.enumerateObjects { phAsset, _, _ in
            let asset = Asset(from: phAsset)
            fetchedAssets.append(asset)
            cache[asset.id] = phAsset
        }

        // Process videos
        videoResults.enumerateObjects { phAsset, _, _ in
            let asset = Asset(from: phAsset)
            fetchedAssets.append(asset)
            cache[asset.id] = phAsset
        }

        // Sort by creation date descending
        fetchedAssets.sort { $0.creationDate > $1.creationDate }

        await MainActor.run {
            self.phAssetCache = cache
            self.assets = fetchedAssets
            self.isLoading = false
        }

        print("[PhotoLibrary] Fetched \(fetchedAssets.count) assets (\(imageResults.count) images, \(videoResults.count) videos)")
    }

    // MARK: - Asset Retrieval

    func getPHAsset(for assetId: String) -> PHAsset? {
        if let cached = phAssetCache[assetId] {
            return cached
        }

        // Try to fetch from library if not cached
        let localIdentifier = assetId.replacingOccurrences(of: "_", with: "/")
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        if let asset = result.firstObject {
            phAssetCache[assetId] = asset
            return asset
        }

        return nil
    }

    // MARK: - File Size

    func getAssetFileSize(_ asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        var totalSize: Int64 = 0

        for resource in resources {
            if let size = resource.value(forKey: "fileSize") as? Int64 {
                totalSize += size
            }
        }

        return totalSize
    }

    // MARK: - File Data Retrieval

    func getImageData(for assetId: String, completion: @escaping (Data?) -> Void) {
        guard let phAsset = getPHAsset(for: assetId) else {
            completion(nil)
            return
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        imageManager.requestImageDataAndOrientation(for: phAsset, options: options) { data, _, _, _ in
            completion(data)
        }
    }

    func getVideoData(for assetId: String, completion: @escaping (Data?) -> Void) {
        guard let phAsset = getPHAsset(for: assetId) else {
            completion(nil)
            return
        }

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        imageManager.requestAVAsset(forVideo: phAsset, options: options) { avAsset, _, _ in
            guard let urlAsset = avAsset as? AVURLAsset else {
                // Try exporting if direct URL not available
                self.exportVideoData(phAsset: phAsset, completion: completion)
                return
            }

            do {
                let data = try Data(contentsOf: urlAsset.url)
                completion(data)
            } catch {
                print("[PhotoLibrary] Failed to read video data: \(error)")
                completion(nil)
            }
        }
    }

    private func exportVideoData(phAsset: PHAsset, completion: @escaping (Data?) -> Void) {
        let resources = PHAssetResource.assetResources(for: phAsset)
        guard let videoResource = resources.first(where: { $0.type == .video }) else {
            completion(nil)
            return
        }

        var data = Data()
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        PHAssetResourceManager.default().requestData(for: videoResource, options: options) { chunk in
            data.append(chunk)
        } completionHandler: { error in
            if let error = error {
                print("[PhotoLibrary] Video export error: \(error)")
                completion(nil)
            } else {
                completion(data)
            }
        }
    }

    // MARK: - Live Photo Resources

    func getLivePhotoResources(for assetId: String) -> (photo: PHAssetResource?, video: PHAssetResource?)? {
        guard let phAsset = getPHAsset(for: assetId) else { return nil }

        let resources = PHAssetResource.assetResources(for: phAsset)

        let photoResource = resources.first { $0.type == .photo || $0.type == .fullSizePhoto }
        let videoResource = resources.first { $0.type == .pairedVideo || $0.type == .fullSizePairedVideo }

        return (photoResource, videoResource)
    }

    func getLivePhotoImageData(for assetId: String, completion: @escaping (Data?) -> Void) {
        guard let resources = getLivePhotoResources(for: assetId),
              let photoResource = resources.photo else {
            completion(nil)
            return
        }

        var data = Data()
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        PHAssetResourceManager.default().requestData(for: photoResource, options: options) { chunk in
            data.append(chunk)
        } completionHandler: { error in
            completion(error == nil ? data : nil)
        }
    }

    func getLivePhotoVideoData(for assetId: String, completion: @escaping (Data?) -> Void) {
        guard let resources = getLivePhotoResources(for: assetId),
              let videoResource = resources.video else {
            completion(nil)
            return
        }

        var data = Data()
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        PHAssetResourceManager.default().requestData(for: videoResource, options: options) { chunk in
            data.append(chunk)
        } completionHandler: { error in
            completion(error == nil ? data : nil)
        }
    }

    // MARK: - Asset List JSON

    func buildAssetListResponse() -> AssetListResponse {
        let metadataList = assets.map { $0.toMetadata() }

        let photosCount = assets.filter { $0.type == .photo || $0.type == .livePhoto }.count
        let videosCount = assets.filter { $0.type == .video }.count
        let totalSize = assets.reduce(Int64(0)) { $0 + $1.sizeBytes }

        return AssetListResponse(
            assets: metadataList,
            totalCount: assets.count,
            photosCount: photosCount,
            videosCount: videosCount,
            totalSizeBytes: totalSize
        )
    }

    func buildAssetListJSON() -> Data? {
        let response = buildAssetListResponse()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            return try encoder.encode(response)
        } catch {
            print("[PhotoLibrary] JSON encoding error: \(error)")
            return nil
        }
    }
}
