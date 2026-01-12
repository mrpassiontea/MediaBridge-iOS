import Foundation

struct PCDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let ipAddress: String
    let port: Int
}
