import Foundation
import Combine
import UIKit

// MARK: - Connection State

enum ConnectionState: Equatable {
    case idle
    case searching
    case awaitingPIN
    case verifying
    case connected
    case syncing(progress: Double)
    case ready
    case error(String)

    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.searching, .searching),
             (.awaitingPIN, .awaitingPIN),
             (.verifying, .verifying),
             (.connected, .connected),
             (.ready, .ready):
            return true
        case (.syncing(let p1), .syncing(let p2)):
            return p1 == p2
        case (.error(let e1), .error(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
}

// MARK: - Connection Manager

class ConnectionManager: ObservableObject, TCPConnectionDelegate {
    static let shared = ConnectionManager()

    // Published state
    @Published private(set) var state: ConnectionState = .idle
    @Published private(set) var connectedDeviceName: String?
    @Published private(set) var pinCode: String?
    @Published private(set) var pinTimeRemaining: Int = 0
    @Published private(set) var syncProgress: Double = 0
    @Published private(set) var assetCount: Int = 0
    @Published private(set) var photoCount: Int = 0
    @Published private(set) var videoCount: Int = 0

    // Services
    private let tcpServer = TCPServerService.shared
    private let bonjourService = BonjourService.shared
    private let pinService = PINService.shared
    private let photoService = PhotoLibraryService.shared
    private let thumbnailService = ThumbnailService.shared

    private var cancellables = Set<AnyCancellable>()
    private var syncTask: Task<Void, Never>?

    private init() {
        setupBindings()
        setupPINExpirationHandler()
    }

    private func setupPINExpirationHandler() {
        pinService.setOnPINExpired { [weak self] in
            guard let self = self,
                  self.state == .awaitingPIN || self.state == .verifying else { return }

            DispatchQueue.main.async {
                self.tcpServer.sendNotification(message: "PIN expired. Sending new PIN...")
            }

            let newPIN = self.pinService.regeneratePIN()
            self.tcpServer.sendPinChallenge(pin: newPIN)
        }
    }

    private func setupBindings() {
        // Bind PIN time remaining
        pinService.$timeRemaining
            .receive(on: DispatchQueue.main)
            .assign(to: &$pinTimeRemaining)

        // Bind PIN code
        pinService.$currentPIN
            .receive(on: DispatchQueue.main)
            .assign(to: &$pinCode)
    }

    // MARK: - Lifecycle

    func start() async {
        // Request photo library access
        let authorized = await photoService.requestAuthorization()
        guard authorized else {
            await MainActor.run {
                state = .error("Photo library access denied")
            }
            return
        }

        // Fetch assets
        await photoService.fetchAllAssets()

        await MainActor.run {
            assetCount = photoService.assets.count
            photoCount = photoService.assets.filter { $0.type == .photo || $0.type == .livePhoto }.count
            videoCount = photoService.assets.filter { $0.type == .video }.count
        }

        // Start TCP server
        do {
            tcpServer.delegate = self
            try tcpServer.start()
        } catch {
            await MainActor.run {
                state = .error("Failed to start server: \(error.localizedDescription)")
            }
            return
        }

        // Configure Bonjour advertisement on the TCP listener
        if let listener = tcpServer.listener {
            bonjourService.configureAdvertisement(on: listener)
        }

        // Start Bonjour discovery
        bonjourService.startAll()

        await MainActor.run {
            state = .searching
        }
    }

    func stop() {
        syncTask?.cancel()
        tcpServer.stop()
        bonjourService.stopAll()
        pinService.cancelPIN()

        state = .idle
        connectedDeviceName = nil
        pinCode = nil
    }

    // MARK: - Connection Flow

    func disconnect() {
        tcpServer.sendDisconnect()
        cleanup()

        state = .searching
    }

    private func cleanup() {
        syncTask?.cancel()
        pinService.cancelPIN()
        connectedDeviceName = nil
        syncProgress = 0
    }

    // MARK: - TCPConnectionDelegate

    func connectionDidReceiveCommand(_ command: ProtocolCommand, info: String, payload: Data?) {
        print("[ConnectionManager] Received: \(command.description), info: \(info)")

        switch command {
        case .connect:
            handleConnect(deviceName: info)

        case .verifyPin:
            handleVerifyPIN(pin: info)

        case .listAssets:
            handleListAssets()

        case .getThumbnail:
            handleGetThumbnail(assetId: info)

        case .getFullFile:
            handleGetFullFile(assetId: info)

        case .disconnect:
            handleDisconnect()

        default:
            print("[ConnectionManager] Unhandled command: \(command)")
        }
    }

    func connectionDidClose() {
        print("[ConnectionManager] Connection closed")
        cleanup()
        state = .searching
    }

    func connectionDidFail(error: Error) {
        print("[ConnectionManager] Connection failed: \(error)")
        cleanup()
        state = .error(error.localizedDescription)

        // Retry after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if case .error = self?.state {
                self?.state = .searching
            }
        }
    }

    // MARK: - Command Handlers

    private func handleConnect(deviceName: String) {
        connectedDeviceName = deviceName.isEmpty ? "Unknown PC" : deviceName
        state = .awaitingPIN

        // Generate PIN and send challenge
        let pin = pinService.generatePIN()
        tcpServer.sendPinChallenge(pin: pin)

        // Trigger haptic
        triggerHaptic(.medium)
    }

    private func handleVerifyPIN(pin: String) {
        state = .verifying

        let result = pinService.verify(pin: pin)

        switch result {
        case .success:
            tcpServer.sendPinOK()
            state = .connected
            triggerHaptic(.success)

            // Start syncing
            startSync()

        case .failed(let remaining):
            tcpServer.sendPinFail()
            state = .awaitingPIN
            tcpServer.sendNotification(message: "Wrong PIN. \(remaining) attempts remaining.")
            triggerHaptic(.error)

        case .expired:
            tcpServer.sendPinFail()
            tcpServer.sendNotification(message: "PIN expired")
            disconnect()
            triggerHaptic(.error)

        case .maxAttemptsReached:
            tcpServer.sendPinFail()
            tcpServer.sendNotification(message: "Too many failed attempts")
            disconnect()
            triggerHaptic(.error)
        }
    }

    private func handleListAssets() {
        guard let json = photoService.buildAssetListJSON() else {
            print("[ConnectionManager] Failed to build asset list JSON")
            return
        }

        tcpServer.sendAssetList(json: json)
    }

    private func handleGetThumbnail(assetId: String) {
        thumbnailService.getThumbnail(for: assetId) { [weak self] data in
            guard let data = data else {
                print("[ConnectionManager] No thumbnail for asset: \(assetId)")
                return
            }
            self?.tcpServer.sendThumbnail(assetId: assetId, data: data)
        }
    }

    private func handleGetFullFile(assetId: String) {
        // Determine asset type and get appropriate data
        guard let asset = photoService.assets.first(where: { $0.id == assetId }) else {
            print("[ConnectionManager] Asset not found: \(assetId)")
            return
        }

        switch asset.type {
        case .photo:
            photoService.getImageData(for: assetId) { [weak self] data in
                guard let data = data else { return }
                self?.tcpServer.sendFileData(assetId: assetId, data: data)
            }

        case .video:
            photoService.getVideoData(for: assetId) { [weak self] data in
                guard let data = data else { return }
                self?.tcpServer.sendFileData(assetId: assetId, data: data)
            }

        case .livePhoto:
            // For Live Photos, send the photo component by default
            // The client can request the video component separately
            photoService.getLivePhotoImageData(for: assetId) { [weak self] data in
                guard let data = data else { return }
                self?.tcpServer.sendFileData(assetId: assetId, data: data)
            }
        }
    }

    private func handleDisconnect() {
        cleanup()
        state = .searching
    }

    // MARK: - Sync Process

    private func startSync() {
        state = .syncing(progress: 0)

        syncTask = Task {
            // Just transition to ready - actual thumbnail sync happens on-demand
            // when PC requests them via GET_THUMBNAIL
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s

            await MainActor.run {
                self.state = .ready
            }
        }
    }

    // MARK: - Haptics

    private func triggerHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
