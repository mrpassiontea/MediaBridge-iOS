import Foundation
import Network

class TCPServerService {
    static let shared = TCPServerService()
    
    private var listener: NWListener?
    
    func start() throws {
        let parameters = NWParameters.tcp
        listener = try NWListener(using: parameters, on: 2347)
        
        listener?.stateUpdateHandler = { state in
            print("Listener state: \(state)")
        }
        
        listener?.newConnectionHandler = { connection in
            print("New connection: \(connection)")
            connection.start(queue: .main)
        }
        
        listener?.start(queue: .main)
    }
    
    func stop() {
        listener?.cancel()
    }
}
