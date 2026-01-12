import Foundation
import Network
import Combine

// MARK: - TCP Client Service
// Connects to Windows PC as a client (iOS initiates connection)

class TCPClientService: ObservableObject {
    static let shared = TCPClientService()

    @Published private(set) var isConnected = false
    @Published private(set) var connectionState: NWConnection.State = .setup

    weak var delegate: TCPConnectionDelegate?

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.mediabridge.client")
    private var isReading = false

    private init() {}

    // MARK: - Connection Control

    /// Connect to a discovered Windows PC
    func connect(to device: PCDevice) {
        // Cancel any existing connection
        disconnect()

        let host = NWEndpoint.Host(device.ipAddress)
        guard let port = NWEndpoint.Port(rawValue: UInt16(device.port)) else {
            print("[TCP Client] Invalid port: \(device.port)")
            return
        }

        print("[TCP Client] Connecting to \(device.ipAddress):\(device.port)")

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        connection = NWConnection(host: host, port: port, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            self?.handleStateChange(state)
        }

        connection?.start(queue: queue)
    }

    /// Connect using endpoint directly (from Bonjour resolution)
    func connect(to endpoint: NWEndpoint) {
        disconnect()

        print("[TCP Client] Connecting to endpoint: \(endpoint)")

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        connection = NWConnection(to: endpoint, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            self?.handleStateChange(state)
        }

        connection?.start(queue: queue)
    }

    func disconnect() {
        isReading = false
        connection?.cancel()
        connection = nil

        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionState = .setup
        }
    }

    private func handleStateChange(_ state: NWConnection.State) {
        print("[TCP Client] State: \(state)")

        DispatchQueue.main.async {
            self.connectionState = state
        }

        switch state {
        case .ready:
            print("[TCP Client] Connected successfully")
            DispatchQueue.main.async {
                self.isConnected = true
                // Notify ConnectionManager that connection is ready
                ConnectionManager.shared.onConnectionReady()
            }
            startReceiving()

        case .failed(let error):
            print("[TCP Client] Connection failed: \(error)")
            DispatchQueue.main.async {
                self.isConnected = false
                self.delegate?.connectionDidFail(error: error)
            }

        case .cancelled:
            print("[TCP Client] Connection cancelled")
            DispatchQueue.main.async {
                self.isConnected = false
                self.delegate?.connectionDidClose()
            }

        case .waiting(let error):
            print("[TCP Client] Waiting: \(error)")

        default:
            break
        }
    }

    // MARK: - Receiving

    private func startReceiving() {
        guard !isReading else { return }
        isReading = true
        receiveHeader()
    }

    private func receiveHeader() {
        guard isReading else { return }

        connection?.receive(minimumIncompleteLength: ProtocolConstants.headerSize,
                           maximumLength: ProtocolConstants.headerSize) { [weak self] data, _, isComplete, error in
            guard let self = self, self.isReading else { return }

            if let error = error {
                print("[TCP Client] Receive error: \(error)")
                self.isReading = false
                DispatchQueue.main.async {
                    self.delegate?.connectionDidFail(error: error)
                }
                return
            }

            if isComplete {
                print("[TCP Client] Connection closed by peer")
                self.isReading = false
                DispatchQueue.main.async {
                    self.delegate?.connectionDidClose()
                }
                return
            }

            guard let data = data, let header = ProtocolHeader.from(data: data) else {
                print("[TCP Client] Invalid header received")
                self.receiveHeader()
                return
            }

            print("[TCP Client] Received: \(header.command.description), size: \(header.size), info: \(header.info)")

            if header.size > 0 {
                self.receivePayload(header: header, remaining: Int(header.size))
            } else {
                DispatchQueue.main.async {
                    self.delegate?.connectionDidReceiveCommand(header.command, info: header.info, payload: nil)
                }
                self.receiveHeader()
            }
        }
    }

    private func receivePayload(header: ProtocolHeader, remaining: Int, accumulated: Data = Data()) {
        guard isReading else { return }

        let chunkSize = min(remaining, 65536)  // Read in 64KB chunks

        connection?.receive(minimumIncompleteLength: chunkSize,
                           maximumLength: chunkSize) { [weak self] data, _, isComplete, error in
            guard let self = self, self.isReading else { return }

            if let error = error {
                print("[TCP Client] Payload receive error: \(error)")
                self.isReading = false
                return
            }

            guard let data = data else {
                self.receiveHeader()
                return
            }

            var newAccumulated = accumulated
            newAccumulated.append(data)

            let newRemaining = remaining - data.count

            if newRemaining <= 0 {
                DispatchQueue.main.async {
                    self.delegate?.connectionDidReceiveCommand(header.command, info: header.info, payload: newAccumulated)
                }
                self.receiveHeader()
            } else {
                self.receivePayload(header: header, remaining: newRemaining, accumulated: newAccumulated)
            }
        }
    }

    // MARK: - Sending

    func send(packet: ProtocolPacket, completion: ((Error?) -> Void)? = nil) {
        let data = packet.toData()

        connection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("[TCP Client] Send error: \(error)")
            }
            completion?(error)
        })
    }

    func sendHeader(command: ProtocolCommand, size: UInt64 = 0, info: String = "", completion: ((Error?) -> Void)? = nil) {
        let header = ProtocolHeader(command: command, size: size, info: info)

        connection?.send(content: header.toData(), completion: .contentProcessed { error in
            completion?(error)
        })
    }

    func sendData(_ data: Data, completion: ((Error?) -> Void)? = nil) {
        connection?.send(content: data, completion: .contentProcessed { error in
            completion?(error)
        })
    }

    /// Stream large data in chunks with header first
    func streamData(command: ProtocolCommand, info: String = "", data: Data, chunkSize: Int = 65536, completion: ((Error?) -> Void)? = nil) {
        // First send header
        sendHeader(command: command, size: UInt64(data.count), info: info) { [weak self] error in
            guard error == nil else {
                completion?(error)
                return
            }

            // Then stream data in chunks
            self?.sendDataChunks(data: data, offset: 0, chunkSize: chunkSize, completion: completion)
        }
    }

    private func sendDataChunks(data: Data, offset: Int, chunkSize: Int, completion: ((Error?) -> Void)?) {
        guard offset < data.count else {
            completion?(nil)
            return
        }

        let endIndex = min(offset + chunkSize, data.count)
        let chunk = data.subdata(in: offset..<endIndex)

        connection?.send(content: chunk, completion: .contentProcessed { [weak self] error in
            guard error == nil else {
                completion?(error)
                return
            }
            self?.sendDataChunks(data: data, offset: endIndex, chunkSize: chunkSize, completion: completion)
        })
    }

    // MARK: - Convenience Send Methods

    func sendConnect(deviceName: String) {
        send(packet: ProtocolPacket(command: .connect, info: deviceName))
    }

    func sendPinChallenge(pin: String) {
        send(packet: ProtocolPacket(command: .pinChallenge, info: pin))
    }

    func sendPinOK() {
        send(packet: ProtocolPacket(command: .pinOK))
    }

    func sendPinFail() {
        send(packet: ProtocolPacket(command: .pinFail))
    }

    func sendAssetList(json: Data) {
        streamData(command: .assetsList, data: json)
    }

    func sendThumbnail(assetId: String, data: Data) {
        streamData(command: .thumbnailData, info: assetId, data: data)
    }

    func sendFileData(assetId: String, data: Data, completion: ((Error?) -> Void)? = nil) {
        streamData(command: .fileData, info: assetId, data: data, completion: completion)
    }

    func sendDisconnect() {
        send(packet: ProtocolPacket(command: .disconnect)) { [weak self] _ in
            self?.disconnect()
        }
    }

    func sendNotification(message: String) {
        send(packet: ProtocolPacket(command: .notification, info: message))
    }
}
