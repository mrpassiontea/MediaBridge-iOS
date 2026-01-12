import Foundation
import Network
import Combine

// MARK: - Connection Delegate

protocol TCPConnectionDelegate: AnyObject {
    func connectionDidReceiveCommand(_ command: ProtocolCommand, info: String, payload: Data?)
    func connectionDidClose()
    func connectionDidFail(error: Error)
}

// MARK: - Client Connection Handler

class ClientConnection {
    let connection: NWConnection
    weak var delegate: TCPConnectionDelegate?

    private let queue = DispatchQueue(label: "com.mediabridge.connection")
    private var isReading = false

    init(connection: NWConnection, delegate: TCPConnectionDelegate?) {
        self.connection = connection
        self.delegate = delegate
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            self?.handleStateChange(state)
        }
        connection.start(queue: queue)
    }

    func stop() {
        connection.cancel()
    }

    private func handleStateChange(_ state: NWConnection.State) {
        switch state {
        case .ready:
            print("[TCP] Connection ready")
            startReceiving()
        case .failed(let error):
            print("[TCP] Connection failed: \(error)")
            DispatchQueue.main.async {
                self.delegate?.connectionDidFail(error: error)
            }
        case .cancelled:
            print("[TCP] Connection cancelled")
            DispatchQueue.main.async {
                self.delegate?.connectionDidClose()
            }
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
        connection.receive(minimumIncompleteLength: ProtocolConstants.headerSize,
                          maximumLength: ProtocolConstants.headerSize) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                print("[TCP] Receive error: \(error)")
                self.isReading = false
                DispatchQueue.main.async {
                    self.delegate?.connectionDidFail(error: error)
                }
                return
            }

            if isComplete {
                print("[TCP] Connection closed by peer")
                self.isReading = false
                DispatchQueue.main.async {
                    self.delegate?.connectionDidClose()
                }
                return
            }

            guard let data = data, let header = ProtocolHeader.from(data: data) else {
                print("[TCP] Invalid header received")
                self.receiveHeader()
                return
            }

            print("[TCP] Received command: \(header.command.description), size: \(header.size), info: \(header.info)")

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
        let chunkSize = min(remaining, 65536)  // Read in 64KB chunks

        connection.receive(minimumIncompleteLength: chunkSize,
                          maximumLength: chunkSize) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                print("[TCP] Payload receive error: \(error)")
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

        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("[TCP] Send error: \(error)")
            }
            completion?(error)
        })
    }

    func sendHeader(command: ProtocolCommand, size: UInt64 = 0, info: String = "", completion: ((Error?) -> Void)? = nil) {
        let header = ProtocolHeader(command: command, size: size, info: info)

        connection.send(content: header.toData(), completion: .contentProcessed { error in
            completion?(error)
        })
    }

    func sendData(_ data: Data, completion: ((Error?) -> Void)? = nil) {
        connection.send(content: data, completion: .contentProcessed { error in
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

        connection.send(content: chunk, completion: .contentProcessed { [weak self] error in
            guard error == nil else {
                completion?(error)
                return
            }
            self?.sendDataChunks(data: data, offset: endIndex, chunkSize: chunkSize, completion: completion)
        })
    }
}

// MARK: - TCP Server Service

class TCPServerService: ObservableObject {
    static let shared = TCPServerService()

    @Published private(set) var isRunning = false
    @Published private(set) var currentConnection: ClientConnection?

    weak var delegate: TCPConnectionDelegate?

    private var _listener: NWListener?
    var listener: NWListener? { _listener }
    let queue = DispatchQueue(label: "com.mediabridge.server")

    private init() {}

    // MARK: - Server Control

    func start() throws {
        guard !isRunning else { return }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: ProtocolConstants.port)!)
        _listener = listener

        listener.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleListenerState(state)
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener.start(queue: queue)
    }

    func stop() {
        currentConnection?.stop()
        currentConnection = nil
        listener?.cancel()
        _listener = nil

        DispatchQueue.main.async {
            self.isRunning = false
        }
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("[TCP Server] Listening on port \(ProtocolConstants.port)")
            isRunning = true
        case .failed(let error):
            print("[TCP Server] Failed: \(error)")
            isRunning = false
        case .cancelled:
            print("[TCP Server] Cancelled")
            isRunning = false
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        print("[TCP Server] New connection from: \(connection.endpoint)")

        // Only allow one connection at a time
        currentConnection?.stop()

        DispatchQueue.main.async {
            let clientConnection = ClientConnection(connection: connection, delegate: self.delegate)
            self.currentConnection = clientConnection
            clientConnection.start()
        }
    }

    // MARK: - Sending Helpers

    func sendPinChallenge(pin: String) {
        currentConnection?.send(packet: ProtocolPacket(command: .pinChallenge, info: pin))
    }

    func sendPinOK() {
        currentConnection?.send(packet: ProtocolPacket(command: .pinOK))
    }

    func sendPinFail() {
        currentConnection?.send(packet: ProtocolPacket(command: .pinFail))
    }

    func sendAssetList(json: Data) {
        currentConnection?.streamData(command: .assetsList, data: json)
    }

    func sendThumbnail(assetId: String, data: Data) {
        currentConnection?.streamData(command: .thumbnailData, info: assetId, data: data)
    }

    func sendFileData(assetId: String, data: Data, completion: ((Error?) -> Void)? = nil) {
        currentConnection?.streamData(command: .fileData, info: assetId, data: data, completion: completion)
    }

    func sendDisconnect() {
        currentConnection?.send(packet: ProtocolPacket(command: .disconnect)) { [weak self] _ in
            self?.currentConnection?.stop()
            DispatchQueue.main.async {
                self?.currentConnection = nil
            }
        }
    }

    func sendNotification(message: String) {
        currentConnection?.send(packet: ProtocolPacket(command: .notification, info: message))
    }
}
