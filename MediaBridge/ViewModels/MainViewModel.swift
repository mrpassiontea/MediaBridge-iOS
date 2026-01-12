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
            .assign(to: &$devices)

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
                if let name = name {
                    self?.connectedDevice = PCDevice(id: UUID(), name: name, ipAddress: "", port: 0)
                } else {
                    self?.connectedDevice = nil
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
        case .idle, .searching:
            state = devices.isEmpty ? .searching : .pcList
            errorMessage = nil

        case .awaitingPIN, .verifying:
            state = .verifying

        case .connected, .syncing:
            state = .connected

        case .ready:
            state = .ready

        case .error(let message):
            errorMessage = message
            // Stay in current state but show error
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

    func connect(to device: PCDevice) {
        // For now, we wait for the PC to connect to us
        // The device list shows PCs that are running MediaBridge
        // When user taps "Connect", we're essentially selecting this device
        // The actual connection is initiated by the PC

        connectedDevice = device
        state = .verifying

        // Generate PIN for this connection
        let pin = PINService.shared.generatePIN()
        pinCode = pin

        // In the real flow, the PC connects to us and we send the PIN challenge
        // For testing, simulate the flow
        #if DEBUG
        simulateConnectionFlow(device: device)
        #endif
    }

    #if DEBUG
    private func simulateConnectionFlow(device: PCDevice) {
        // Simulate PIN acceptance for testing
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard self?.state == .verifying else { return }

            // Simulate successful verification
            self?.state = .connected
            self?.syncProgress = 0

            // Simulate sync progress
            self?.simulateSync()
        }
    }

    private func simulateSync() {
        var progress: Double = 0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            progress += 0.05
            self?.syncProgress = min(progress, 1.0)

            if progress >= 1.0 {
                timer.invalidate()
                self?.state = .ready
            }
        }
    }
    #endif

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
        state = .searching
        startServices()
    }
}
