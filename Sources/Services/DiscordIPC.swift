import Foundation
import AppKit

// MARK: - Discord IPC Client
class DiscordIPC {
    static let shared = DiscordIPC()
    private var socketFd: Int32 = -1
    private var currentClientId: String = ""
    private var isConnected = false
    private let queue = DispatchQueue(label: "com.nino.switchrpc.ipc", qos: .userInitiated)
    
    static func isDiscordAppRunning() -> Bool {
        let discordIds = ["com.hnc.Discord", "com.hnc.DiscordPTB", "com.hnc.DiscordCanary", "com.hnc.DiscordDevelopment"]
        return NSWorkspace.shared.runningApplications.contains { app in
            if let bid = app.bundleIdentifier, discordIds.contains(bid) { return true }
            if let name = app.localizedName, name.lowercased().contains("discord") { return true }
            return false
        }
    }
    
    private func connectSync(clientId: String) -> (success: Bool, error: String?) {
        if isConnected && currentClientId == clientId { return (true, nil) }
        if isConnected { disconnectSync() }
        
        guard Self.isDiscordAppRunning() else {
            return (false, L10n.tr("Discord is not running on your Mac. Please launch Discord first.", "Discord n'est pas ouvert sur votre Mac. Veuillez lancer Discord."))
        }
        
        let dirs = [ProcessInfo.processInfo.environment["TMPDIR"] ?? "/tmp", "/tmp"]
        var connectedFd: Int32 = -1
        
        for dir in dirs {
            let normalizedDir = dir.hasSuffix("/") ? dir : "\(dir)/"
            for i in 0..<10 {
                let path = "\(normalizedDir)discord-ipc-\(i)"
                guard FileManager.default.fileExists(atPath: path) else { continue }
                
                let fd = socket(AF_UNIX, SOCK_STREAM, 0)
                if fd < 0 { continue }
                
                var timeout = timeval(tv_sec: 1, tv_usec: 500000)
                setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
                setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
                
                var addr = sockaddr_un()
                addr.sun_family = sa_family_t(AF_UNIX)
                let maxLen = MemoryLayout.size(ofValue: addr.sun_path)
                withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
                    path.withCString { cstr in _ = strncpy(ptr, cstr, maxLen - 1) }
                }
                
                let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
                let res = withUnsafePointer(to: &addr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        Darwin.connect(fd, sa, addrLen)
                    }
                }
                
                if res != 0 {
                    close(fd)
                    continue
                }
                
                // Test handshake directement sur ce socket
                let handshake: [String: Any] = ["v": 1, "client_id": clientId]
                guard let data = try? JSONSerialization.data(withJSONObject: handshake) else {
                    close(fd)
                    continue
                }
                
                var op: UInt32 = 0
                var len = UInt32(data.count)
                var packet = Data()
                packet.append(Data(bytes: &op, count: 4))
                packet.append(Data(bytes: &len, count: 4))
                packet.append(data)
                
                let writeRes = packet.withUnsafeBytes { ptr in
                    Darwin.write(fd, ptr.baseAddress!, packet.count)
                }
                guard writeRes == packet.count else {
                    close(fd)
                    continue
                }
                
                var header = [UInt8](repeating: 0, count: 8)
                let bytesRead = Darwin.read(fd, &header, 8)
                if bytesRead >= 8 {
                    // Handshake validé avec succès sur ce socket !
                    connectedFd = fd
                    break
                } else {
                    close(fd)
                }
            }
            if connectedFd >= 0 { break }
        }
        
        guard connectedFd >= 0 else {
            return (false, L10n.tr("Cannot connect to Discord Rich Presence.", "Impossible de se connecter à Discord Rich Presence."))
        }
        
        self.socketFd = connectedFd
        self.currentClientId = clientId
        self.isConnected = true
        return (true, nil)
    }
    
    func setGame(_ game: SavedGame, app: DiscordApp, startTime: Int, onResult: @escaping (Bool, String?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let conn = self.connectSync(clientId: app.clientId)
            if !conn.success {
                DispatchQueue.main.async {
                    onResult(false, conn.error)
                }
                return
            }
            
            // Nettoyage et assainissement strict des chaînes (suppression caractères de contrôle invisibles)
            func sanitizeString(_ input: String, maxLength: Int) -> String {
                let filtered = input.unicodeScalars.filter { scalar in
                    // Garde les caractères imprimables et emojis valides, exclut les octets nuls et caractères de contrôle dangereux
                    return !CharacterSet.controlCharacters.contains(scalar) || scalar == "\n"
                }
                var clean = String(String.UnicodeScalarView(filtered)).trimmingCharacters(in: .whitespacesAndNewlines)
                if clean.count > maxLength {
                    clean = String(clean.prefix(maxLength - 3)) + "..."
                }
                return clean
            }
            
            var cleanDetails = sanitizeString(game.name, maxLength: 128)
            if cleanDetails.isEmpty { cleanDetails = L10n.tr("Game", "Jeu") }
            
            var activityDict: [String: Any] = [
                "type": game.activityType.rawValue,
                "details": cleanDetails
            ]
            
            if AppState.shared.store.settings.showElapsedTime {
                activityDict["timestamps"] = ["start": startTime]
            }
            
            var cleanStatus = sanitizeString(game.status, maxLength: 128)
            if cleanStatus.isEmpty {
                cleanStatus = L10n.tr("Playing", "En cours")
            }
            activityDict["state"] = cleanStatus
            
            if !game.imageUrl.isEmpty && game.imageUrl.hasPrefix("http") {
                activityDict["assets"] = [
                    "large_image": game.imageUrl,
                    "large_text": cleanDetails
                ]
            }
            
            let payload: [String: Any] = [
                "cmd": "SET_ACTIVITY",
                "args": [
                    "pid": ProcessInfo.processInfo.processIdentifier,
                    "activity": activityDict
                ],
                "nonce": UUID().uuidString
            ]
            
            guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
                DispatchQueue.main.async { onResult(false, L10n.tr("Payload serialization error", "Erreur sérialisation payload")) }
                return
            }
            var op: UInt32 = 1
            var len = UInt32(data.count)
            var packet = Data()
            packet.append(Data(bytes: &op, count: 4))
            packet.append(Data(bytes: &len, count: 4))
            packet.append(data)
            _ = packet.withUnsafeBytes { ptr in
                Darwin.write(self.socketFd, ptr.baseAddress!, packet.count)
            }
            
            var resHeader = [UInt8](repeating: 0, count: 8)
            let rh = Darwin.read(self.socketFd, &resHeader, 8)
            if rh >= 8 {
                let resLen = resHeader[4..<8].withUnsafeBytes { $0.load(as: UInt32.self) }
                if resLen > 0 {
                    var resBody = [UInt8](repeating: 0, count: Int(resLen))
                    _ = Darwin.read(self.socketFd, &resBody, Int(resLen))
                    if let json = try? JSONSerialization.jsonObject(with: Data(resBody)) as? [String: Any],
                       let evt = json["evt"] as? String, evt == "ERROR",
                       let dataObj = json["data"] as? [String: Any] {
                        DispatchQueue.main.async {
                            let code = dataObj["code"] as? Int ?? 4000
                            onResult(false, L10n.tr("Discord error: \(code)", "Erreur Discord : \(code)"))
                        }
                        return
                    }
                }
            }
            
            DispatchQueue.main.async {
                onResult(true, nil)
            }
        }
    }
    
    func clearActivity() {
        queue.async { [weak self] in
            guard let self = self, self.isConnected, self.socketFd >= 0 else { return }
            let clear: [String: Any] = [
                "cmd": "SET_ACTIVITY",
                "args": ["pid": ProcessInfo.processInfo.processIdentifier, "activity": NSNull()],
                "nonce": UUID().uuidString
            ]
            if let data = try? JSONSerialization.data(withJSONObject: clear) {
                var op: UInt32 = 1
                var len = UInt32(data.count)
                var packet = Data()
                packet.append(Data(bytes: &op, count: 4))
                packet.append(Data(bytes: &len, count: 4))
                packet.append(data)
                _ = packet.withUnsafeBytes { ptr in
                    Darwin.write(self.socketFd, ptr.baseAddress!, packet.count)
                }
                var resHeader = [UInt8](repeating: 0, count: 8)
                _ = Darwin.read(self.socketFd, &resHeader, 8)
            }
        }
    }
    
    private func disconnectSync() {
        if isConnected && socketFd >= 0 {
            let clear: [String: Any] = [
                "cmd": "SET_ACTIVITY",
                "args": ["pid": ProcessInfo.processInfo.processIdentifier, "activity": NSNull()],
                "nonce": UUID().uuidString
            ]
            if let data = try? JSONSerialization.data(withJSONObject: clear) {
                var op: UInt32 = 1
                var len = UInt32(data.count)
                var packet = Data()
                packet.append(Data(bytes: &op, count: 4))
                packet.append(Data(bytes: &len, count: 4))
                packet.append(data)
                _ = packet.withUnsafeBytes { ptr in
                    Darwin.write(self.socketFd, ptr.baseAddress!, packet.count)
                }
                var resHeader = [UInt8](repeating: 0, count: 8)
                _ = Darwin.read(self.socketFd, &resHeader, 8)
            }
            close(socketFd)
            socketFd = -1
            isConnected = false
            currentClientId = ""
        }
    }
    
    func disconnect() {
        queue.async { [weak self] in
            self?.disconnectSync()
        }
    }
}
