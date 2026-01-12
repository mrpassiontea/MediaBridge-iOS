import Foundation
import Photos

enum AssetType: String, Codable {
    case photo
    case video
    case livePhoto = "live_photo"
}

struct Asset: Identifiable {
    let id: String
    let localIdentifier: String
    let filename: String
    let type: AssetType
    let width: Int
    let height: Int
    let durationSeconds: Double?
    let creationDate: Date
    let isLivePhoto: Bool

    // Reference to underlying PHAsset for data retrieval
    weak var phAsset: PHAsset?

    // Computed file size (retrieved on demand as it requires I/O)
    var sizeBytes: Int64 {
        guard let asset = phAsset else { return 0 }
        return PhotoLibraryService.shared.getAssetFileSize(asset)
    }

    init(from phAsset: PHAsset) {
        self.localIdentifier = phAsset.localIdentifier
        self.id = phAsset.localIdentifier.replacingOccurrences(of: "/", with: "_")
        self.phAsset = phAsset

        // Get filename from resources
        let resources = PHAssetResource.assetResources(for: phAsset)
        self.filename = resources.first?.originalFilename ?? "Unknown"

        // Determine type
        let isLive = phAsset.mediaSubtypes.contains(.photoLive)
        self.isLivePhoto = isLive

        switch phAsset.mediaType {
        case .image:
            self.type = isLive ? .livePhoto : .photo
        case .video:
            self.type = .video
        default:
            self.type = .photo
        }

        self.width = phAsset.pixelWidth
        self.height = phAsset.pixelHeight
        self.durationSeconds = phAsset.mediaType == .video ? phAsset.duration : nil
        self.creationDate = phAsset.creationDate ?? Date()
    }

    /// Convert to protocol metadata format
    func toMetadata() -> AssetMetadata {
        let dateFormatter = ISO8601DateFormatter()
        return AssetMetadata(
            id: id,
            filename: filename,
            type: type.rawValue,
            sizeBytes: sizeBytes,
            width: width,
            height: height,
            durationSeconds: durationSeconds,
            creationDate: dateFormatter.string(from: creationDate),
            isLivePhoto: isLivePhoto
        )
    }
}
