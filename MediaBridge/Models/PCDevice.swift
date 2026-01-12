import Foundation
import Network

struct PCDevice: Identifiable {
    let id: UUID
    let name: String
    let ipAddress: String
    let port: Int
    let endpoint: NWEndpoint?  // Optional resolved endpoint for direct connection

    init(id: UUID = UUID(), name: String, ipAddress: String, port: Int, endpoint: NWEndpoint? = nil) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.port = port
        self.endpoint = endpoint
    }
}

extension PCDevice: Equatable {
    static func == (lhs: PCDevice, rhs: PCDevice) -> Bool {
        // Compare by name and IP (endpoint is not Equatable)
        return lhs.name == rhs.name && lhs.ipAddress == rhs.ipAddress && lhs.port == rhs.port
    }
}
