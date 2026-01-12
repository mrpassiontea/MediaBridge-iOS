import Foundation

// MARK: - Protocol Constants

enum ProtocolConstants {
    static let headerSize = 59
    static let infoFieldSize = 50
    static let port: UInt16 = 2347
    static let serviceType = "_mediabridge._tcp"
    static let serviceDomain = "local."
}

// MARK: - Command Enum

enum ProtocolCommand: UInt8 {
    case connect = 1
    case pinChallenge = 2
    case verifyPin = 3
    case pinOK = 4
    case pinFail = 5
    case listAssets = 6
    case assetsList = 7
    case getThumbnail = 8
    case thumbnailData = 9
    case getFullFile = 10
    case fileData = 11
    case disconnect = 12
    case notification = 13

    var description: String {
        switch self {
        case .connect: return "CONNECT"
        case .pinChallenge: return "PIN_CHALLENGE"
        case .verifyPin: return "VERIFY_PIN"
        case .pinOK: return "PIN_OK"
        case .pinFail: return "PIN_FAIL"
        case .listAssets: return "LIST_ASSETS"
        case .assetsList: return "ASSETS_LIST"
        case .getThumbnail: return "GET_THUMBNAIL"
        case .thumbnailData: return "THUMBNAIL_DATA"
        case .getFullFile: return "GET_FULL_FILE"
        case .fileData: return "FILE_DATA"
        case .disconnect: return "DISCONNECT"
        case .notification: return "NOTIFICATION"
        }
    }
}

// MARK: - Protocol Header

/// 59-byte fixed header structure:
/// - 1 byte: Command ID
/// - 8 bytes: Size (Little Endian UInt64)
/// - 50 bytes: Info (UTF-8, null-padded)
struct ProtocolHeader {
    let command: ProtocolCommand
    let size: UInt64
    let info: String

    init(command: ProtocolCommand, size: UInt64 = 0, info: String = "") {
        self.command = command
        self.size = size
        self.info = info
    }

    /// Serialize header to 59-byte Data
    func toData() -> Data {
        var data = Data(capacity: ProtocolConstants.headerSize)

        // 1 byte: Command ID
        data.append(command.rawValue)

        // 8 bytes: Size (Little Endian)
        var sizeLE = size.littleEndian
        data.append(Data(bytes: &sizeLE, count: 8))

        // 50 bytes: Info (UTF-8, null-padded)
        var infoData = Data(info.utf8.prefix(ProtocolConstants.infoFieldSize))
        // Pad with nulls to exactly 50 bytes
        while infoData.count < ProtocolConstants.infoFieldSize {
            infoData.append(0)
        }
        data.append(infoData)

        return data
    }

    /// Parse header from 59-byte Data
    static func from(data: Data) -> ProtocolHeader? {
        guard data.count >= ProtocolConstants.headerSize else { return nil }

        // 1 byte: Command ID
        guard let command = ProtocolCommand(rawValue: data[0]) else { return nil }

        // 8 bytes: Size (Little Endian)
        let sizeData = data.subdata(in: 1..<9)
        let size = sizeData.withUnsafeBytes { $0.load(as: UInt64.self).littleEndian }

        // 50 bytes: Info (UTF-8, null-terminated)
        let infoData = data.subdata(in: 9..<ProtocolConstants.headerSize)
        let info = String(data: infoData, encoding: .utf8)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) ?? ""

        return ProtocolHeader(command: command, size: size, info: info)
    }
}

// MARK: - Protocol Packet

/// Complete packet with header and optional payload
struct ProtocolPacket {
    let header: ProtocolHeader
    let payload: Data?

    init(command: ProtocolCommand, info: String = "", payload: Data? = nil) {
        self.header = ProtocolHeader(
            command: command,
            size: UInt64(payload?.count ?? 0),
            info: info
        )
        self.payload = payload
    }

    init(header: ProtocolHeader, payload: Data? = nil) {
        self.header = header
        self.payload = payload
    }

    /// Serialize complete packet (header + payload)
    func toData() -> Data {
        var data = header.toData()
        if let payload = payload {
            data.append(payload)
        }
        return data
    }
}

// MARK: - Asset List Response

struct AssetListResponse: Codable {
    let assets: [AssetMetadata]
    let totalCount: Int
    let photosCount: Int
    let videosCount: Int
    let totalSizeBytes: Int64

    enum CodingKeys: String, CodingKey {
        case assets
        case totalCount = "total_count"
        case photosCount = "photos_count"
        case videosCount = "videos_count"
        case totalSizeBytes = "total_size_bytes"
    }
}

struct AssetMetadata: Codable {
    let id: String
    let filename: String
    let type: String  // "photo", "video", "live_photo"
    let sizeBytes: Int64
    let width: Int
    let height: Int
    let durationSeconds: Double?
    let creationDate: String
    let isLivePhoto: Bool

    enum CodingKeys: String, CodingKey {
        case id, filename, type, width, height
        case sizeBytes = "size_bytes"
        case durationSeconds = "duration_seconds"
        case creationDate = "creation_date"
        case isLivePhoto = "is_live_photo"
    }
}
