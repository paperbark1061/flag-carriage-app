import Foundation
import Combine

class ConnectionManager: ObservableObject {
    @Published var isConnected = false
    @Published var lastStatus: CarriageStatus = .init()
    @Published var ipAddress: String = UserDefaults.standard.string(forKey: "savedIP") ?? "192.168.4.1"
    @Published var port: Int = 81
    @Published var errorMessage: String? = nil

    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?

    func connect() {
        guard let url = URL(string: "ws://\(ipAddress):\(port)") else {
            errorMessage = "Invalid IP address"
            return
        }
        UserDefaults.standard.set(ipAddress, forKey: "savedIP")
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveLoop()
        startPing()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isConnected = self.webSocketTask?.state == .running
        }
    }

    func disconnect() {
        pingTimer?.invalidate()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async { self.isConnected = false }
    }

    func send(_ command: String) {
        guard isConnected else { return }
        webSocketTask?.send(.string(command)) { [weak self] error in
            if error != nil { DispatchQueue.main.async { self?.isConnected = false } }
        }
    }

    func forward()  { send("F") }
    func backward() { send("B") }
    func stop()     { send("S") }
    func setSpeed(_ speed: Int) { send("SPD:\(speed)") }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    DispatchQueue.main.async {
                        self.isConnected = true
                        self.parseStatus(text)
                    }
                }
                self.receiveLoop()
            case .failure:
                DispatchQueue.main.async { self.isConnected = false }
            }
        }
    }

    private func parseStatus(_ text: String) {
        var s = CarriageStatus()
        let parts = text.replacingOccurrences(of: "STATUS:", with: "").split(separator: ",")
        for part in parts {
            let kv = part.split(separator: ":")
            guard kv.count == 2 else { continue }
            switch kv[0] {
            case "SPD": s.speed = Int(kv[1]) ?? 0
            case "LA":  s.limitA = kv[1] == "1"
            case "LB":  s.limitB = kv[1] == "1"
            case "IP":  s.ip = String(kv[1])
            default: break
            }
        }
        if let first = parts.first, first.count == 1 { s.direction = String(first) }
        lastStatus = s
    }

    private func startPing() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.webSocketTask?.sendPing { _ in }
        }
    }
}

struct CarriageStatus {
    var direction: String = "S"
    var speed: Int = 0
    var limitA: Bool = false
    var limitB: Bool = false
    var ip: String = ""
}
