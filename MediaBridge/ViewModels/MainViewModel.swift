import SwiftUI
import Combine

class MainViewModel: ObservableObject {
    @Published var state: AppState = .searching
    @Published var devices: [PCDevice] = []
    @Published var pinCode: String?
    @Published var connectedDevice: PCDevice?
    
    init() {
        // Mock data for testing interface
        startMockDiscovery()
    }
    
    private func startMockDiscovery() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.devices = [
                PCDevice(id: UUID(), name: "MacBook Pro", ipAddress: "192.168.1.105", port: 2347)
            ]
        }
    }
    
    func connect(to device: PCDevice) {
        self.connectedDevice = device
        self.state = .verifying
        self.pinCode = "8472" // Mock generated PIN
        
        // Simulate PIN acceptance after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.state == .verifying {
                self.state = .connected
                self.simulateSync()
            }
        }
    }
    
    private func simulateSync() {
        // Simulate syncing phase then ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if self.state == .connected {
                self.state = .ready
            }
        }
    }
    
    func cancelConnection() {
        self.connectedDevice = nil
        self.state = .searching
        self.pinCode = nil
    }
    
    func disconnect() {
        self.connectedDevice = nil
        self.state = .searching
        self.pinCode = nil
    }
}
