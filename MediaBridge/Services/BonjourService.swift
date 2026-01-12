import Foundation
import Network
import Combine
import UIKit

// MARK: - Bonjour Service
// iOS discovers Windows PCs via Bonjour (iOS is client, Windows is server)

class BonjourService: ObservableObject {
    static let shared = BonjourService()

    @Published private(set) var discoveredDevices: [PCDevice] = []
    @Published private(set) var isBrowsing = false

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.mediabridge.bonjour")

    private init() {}

    // MARK: - Browsing (Discover Windows PCs)

    func startBrowsing() {
        guard !isBrowsing else { return }

        // Clear existing devices
        DispatchQueue.main.async {
            self.discoveredDevices = []
        }

        let descriptor = NWBrowser.Descriptor.bonjour(
            type: ProtocolConstants.serviceType,
            domain: ProtocolConstants.serviceDomain
        )

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: descriptor, using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    print("[Bonjour] Browser ready, searching for PCs")
                    self?.isBrowsing = true
                case .failed(let error):
                    print("[Bonjour] Browser failed: \(error)")
                    self?.isBrowsing = false
                case .cancelled:
                    print("[Bonjour] Browser cancelled")
                    self?.isBrowsing = false
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleBrowseResults(results, changes: changes)
        }

        browser?.start(queue: queue)
        print("[Bonjour] Started browsing for \(ProtocolConstants.serviceType)")
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        DispatchQueue.main.async {
            self.isBrowsing = false
            self.discoveredDevices = []
        }
        print("[Bonjour] Stopped browsing")
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                resolveEndpoint(result)
            case .removed(let result):
                removeDevice(result)
            case .changed(old: _, new: let newResult, flags: _):
                resolveEndpoint(newResult)
            case .identical:
                break
            @unknown default:
                break
            }
        }
    }

    private func resolveEndpoint(_ result: NWBrowser.Result) {
        // Extract device name from the result
        let name: String
        switch result.endpoint {
        case .service(let serviceName, _, _, _):
            name = serviceName
        default:
            name = "Unknown PC"
        }

        // Create a connection to resolve the IP address
        let connection = NWConnection(to: result.endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                // Get the resolved IP address
                if let path = connection.currentPath,
                   let endpoint = path.remoteEndpoint {
                    self?.addResolvedDevice(name: name, endpoint: endpoint, browseResult: result)
                }
                connection.cancel()
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }

        connection.start(queue: queue)

        // Timeout for resolution
        queue.asyncAfter(deadline: .now() + 5) {
            if connection.state != .cancelled {
                connection.cancel()
            }
        }
    }

    private func addResolvedDevice(name: String, endpoint: NWEndpoint, browseResult: NWBrowser.Result) {
        var ipAddress = "Unknown"
        var port: UInt16 = ProtocolConstants.port

        switch endpoint {
        case .hostPort(let host, let resolvedPort):
            switch host {
            case .ipv4(let address):
                ipAddress = address.debugDescription
            case .ipv6(let address):
                var ip = address.debugDescription
                // Remove interface suffix (e.g., %en0)
                if let percentIndex = ip.firstIndex(of: "%") {
                    ip.removeSubrange(percentIndex...)
                }
                ipAddress = ip
            case .name(let hostname, _):
                ipAddress = hostname
            @unknown default:
                break
            }
            port = resolvedPort.rawValue
        default:
            break
        }

        let device = PCDevice(
            id: UUID(),
            name: name,
            ipAddress: ipAddress,
            port: Int(port),
            endpoint: browseResult.endpoint
        )

        DispatchQueue.main.async {
            // Filter out own device (shouldn't happen since iOS no longer publishes)
            if name == self.deviceName() {
                print("[Bonjour] Skipped own device: \(name)")
                return
            }

            // Check if device already exists (by name + IP)
            if let existingIndex = self.discoveredDevices.firstIndex(where: { $0.name == name && $0.ipAddress == ipAddress }) {
                // Update existing device
                self.discoveredDevices[existingIndex] = device
                print("[Bonjour] Updated device: \(name) at \(ipAddress):\(port)")
            } else {
                // Add new device
                self.discoveredDevices.append(device)
                print("[Bonjour] Found PC: \(name) at \(ipAddress):\(port)")
            }
        }
    }

    private func removeDevice(_ result: NWBrowser.Result) {
        let name: String
        switch result.endpoint {
        case .service(let serviceName, _, _, _):
            name = serviceName
        default:
            return
        }

        DispatchQueue.main.async {
            self.discoveredDevices.removeAll { $0.name == name }
            print("[Bonjour] Device removed: \(name)")
        }
    }

    // MARK: - Helpers

    private func deviceName() -> String {
        #if os(iOS)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? "MediaBridge iOS"
        #endif
    }

    // MARK: - Lifecycle

    func start() {
        startBrowsing()
    }

    func stop() {
        stopBrowsing()
    }
}
