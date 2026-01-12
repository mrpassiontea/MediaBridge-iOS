import SwiftUI
import Combine

class MainViewModel: ObservableObject {
    // App State
    @Published var state: AppState = .searching
    @Published var devices: [PCDevice] = []
    @Published var pinCode: String?
    @Published var pinTimeRemaining: Int = 0
    @Published var connectedDevice: PCDevice?
    @Published var syncProgress: Double = 0
    @Published var assetCount: Int = 0
    @Published var photoCount: Int = 0
    @Published var videoCount: Int = 0
    @Published var errorMessage: String?

    // Services
    private let connectionManager = ConnectionManager.shared
    private let bonjourService = BonjourService.shared

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Bind connection state to app state
        connectionManager.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connectionState in
                self?.updateAppState(from: connectionState)
            }
            .store(in: &cancellables)

        // Bind discovered devices
        bonjourService.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.devices = devices
                // Update state if we're searching and found devices
                if self?.state == .searching && !devices.isEmpty {
                    self?.state = .pcList
                }
            }
            .store(in: &cancellables)

        // Bind PIN state
        connectionManager.$pinCode
            .receive(on: DispatchQueue.main)
            .assign(to: &$pinCode)

        connectionManager.$pinTimeRemaining
            .receive(on: DispatchQueue.main)
            .assign(to: &$pinTimeRemaining)

        // Bind connected device name
        connectionManager.$connectedDeviceName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                if let name = name, let device = self?.connectedDevice {
                    // Update device name if we have a connected device
                    self?.connectedDevice = PCDevice(id: device.id, name: name, ipAddress: device.ipAddress, port: device.port, endpoint: device.endpoint)
                }
            }
            .store(in: &cancellables)

        // Bind asset counts
        connectionManager.$assetCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$assetCount)

        connectionManager.$photoCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$photoCount)

        connectionManager.$videoCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$videoCount)

        connectionManager.$syncProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$syncProgress)
    }

    private func updateAppState(from connectionState: ConnectionState) {
        switch connectionState {
        case .idle:
            state = .searching
            errorMessage = nil

        case .searching:
            state = devices.isEmpty ? .searching : .pcList
            errorMessage = nil

        case .connecting:
            state = .connecting

        case .awaitingPIN, .verifying:
            state = .verifying

        case .connected, .syncing:
            state = .connected

        case .ready:
            state = .ready

        case .error(let message):
            errorMessage = message
            state = .error
        }
    }

    // MARK: - Actions

    func startServices() {
        Task {
            await connectionManager.start()
        }
    }

    func stopServices() {
        connectionManager.stop()
    }

    /// User taps on a PC to connect - iOS initiates the connection
    func connect(to device: PCDevice) {
        connectedDevice = device
        connectionManager.connectToPC(device)
    }

    func cancelConnection() {
        connectionManager.disconnect()
        connectedDevice = nil
        pinCode = nil
        state = devices.isEmpty ? .searching : .pcList
    }

    func disconnect() {
        connectionManager.disconnect()
        connectedDevice = nil
        pinCode = nil
        state = devices.isEmpty ? .searching : .pcList
    }

    func retryConnection() {
        errorMessage = nil
        if let device = connectedDevice {
            // Retry connecting to the same device
            connectionManager.connectToPC(device)
        } else {
            state = devices.isEmpty ? .searching : .pcList
        }
    }

    func backToDeviceList() {
        cancelConnection()
    }
}
