import Foundation

struct Asset: Codable, Identifiable {
    let id: String
    let filename: String
    let path: String
    let type: String
    let sizeBytes: Int64
    let width: Int
    let height: Int
    let durationSeconds: Double?
    let creationDate: Date
    let thumbnailPath: String
}
