import Foundation
import Network
import Combine
import UIKit

class BonjourService: ObservableObject {
    static let shared = BonjourService()

    @Published private(set) var discoveredDevices: [PCDevice] = []
    @Published private(set) var isPublishing = false
    @Published private(set) var isBrowsing = false

    private var listener: NWListener?
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.mediabridge.bonjour")

    private init() {}

    // MARK: - Publishing (Advertise this iPhone)

    /// Configure Bonjour advertisement on an existing listener (from TCPServerService)
    func configureAdvertisement(on listener: NWListener) {
        listener.service = NWListener.Service(
            name: deviceName(),
            type: ProtocolConstants.serviceType,
            domain: ProtocolConstants.serviceDomain
        )

        listener.serviceRegistrationUpdateHandler = { [weak self] change in
            DispatchQueue.main.async {
                switch change {
                case .add(let endpoint):
                    print("[Bonjour] Service registered: \(endpoint)")
                    self?.isPublishing = true
                case .remove(let endpoint):
                    print("[Bonjour] Service unregistered: \(endpoint)")
                    self?.isPublishing = false
                @unknown default:
                    break
                }
            }
        }

        print("[Bonjour] Configured advertisement on existing listener")
    }

    func startPublishing() {
        // Publishing is now handled by configuring the TCPServerService listener
        // This method is kept for backward compatibility but does nothing on its own
        // Call configureAdvertisement(on:) with the TCP server's listener instead
        print("[Bonjour] startPublishing called - use configureAdvertisement(on:) instead")
    }

    func stopPublishing() {
        // The listener is owned by TCPServerService, so we just update our state
        DispatchQueue.main.async {
            self.isPublishing = false
        }
    }

    // MARK: - Browsing (Discover Windows PCs)

    func startBrowsing() {
        guard !isBrowsing else { return }

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
                    print("[Bonjour] Browser ready, searching for devices")
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
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        DispatchQueue.main.async {
            self.isBrowsing = false
            self.discoveredDevices = []
        }
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
                    self?.addResolvedDevice(name: name, endpoint: endpoint, originalResult: result)
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

    private func addResolvedDevice(name: String, endpoint: NWEndpoint, originalResult: NWBrowser.Result) {
        var ipAddress = "Unknown"
        var port: UInt16 = ProtocolConstants.port

        switch endpoint {
        case .hostPort(let host, let resolvedPort):
            switch host {
            case .ipv4(let address):
                ipAddress = address.debugDescription
            case .ipv6(let address):
                var ip = address.debugDescription
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
            port: Int(port)
        )

        DispatchQueue.main.async {
            // Filter out own device
            if name == self.deviceName() {
                print("[Bonjour] Skipped own device: \(name)")
                return
            }

            // Check if device already exists (by name + IP)
            if !self.discoveredDevices.contains(where: { $0.name == name && $0.ipAddress == ipAddress }) {
                self.discoveredDevices.append(device)
                print("[Bonjour] Found device: \(name) at \(ipAddress):\(port)")
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

    // MARK: - Full Lifecycle

    func startAll() {
        startPublishing()
        startBrowsing()
    }

    func stopAll() {
        stopPublishing()
        stopBrowsing()
    }
}
