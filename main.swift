import Cocoa
import SwiftUI
import Foundation
import Combine

// MARK: - Language Localization (Default: English)
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english = "en"
    case french = "fr"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .french: return "Français"
        }
    }
}

struct L10n {
    static var lang: AppLanguage {
        return AppState.shared.store.settings.language
    }
    
    static func tr(_ en: String, _ fr: String) -> String {
        return lang == .french ? fr : en
    }
}

// MARK: - Activity Type
enum ActivityType: Int, Codable, CaseIterable, Identifiable {
    case playing = 0
    case listening = 2
    case watching = 3
    case competing = 5
    
    var id: Int { self.rawValue }
    
    func localizedLabel(lang: AppLanguage) -> String {
        switch self {
        case .playing: return lang == .french ? "🎮 Joue à" : "🎮 Playing"
        case .watching: return lang == .french ? "📺 Regarde" : "📺 Watching"
        case .listening: return lang == .french ? "🎧 Écoute" : "🎧 Listening to"
        case .competing: return lang == .french ? "🏆 En compétition sur" : "🏆 Competing in"
        }
    }
    
    func localizedDiscordHeader(lang: AppLanguage) -> String {
        switch self {
        case .playing: return lang == .french ? "Joue à" : "Playing"
        case .watching: return lang == .french ? "Regarde" : "Watching"
        case .listening: return lang == .french ? "Écoute" : "Listening to"
        case .competing: return lang == .french ? "En compétition sur" : "Competing in"
        }
    }
    
    var label: String { localizedLabel(lang: L10n.lang) }
    var discordHeader: String { localizedDiscordHeader(lang: L10n.lang) }
}

// MARK: - App Platform
struct DiscordApp: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var clientId: String
}

// MARK: - Game Item
struct SavedGame: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var status: String
    var imageUrl: String
    var appId: UUID
    var activityType: ActivityType = .playing
    
    enum CodingKeys: String, CodingKey {
        case id, name, status, imageUrl, appId, activityType
    }
    
    init(id: UUID = UUID(), name: String, status: String, imageUrl: String, appId: UUID, activityType: ActivityType = .playing) {
        self.id = id
        self.name = name
        self.status = status
        self.imageUrl = imageUrl
        self.appId = appId
        self.activityType = activityType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decode(String.self, forKey: .status)
        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        appId = try container.decode(UUID.self, forKey: .appId)
        activityType = (try? container.decode(ActivityType.self, forKey: .activityType)) ?? .playing
    }
}

// MARK: - Image Memory & Local Disk Storage
class ImageLoader: ObservableObject {
    @Published var image: NSImage?
    private static let cache = NSCache<NSString, NSImage>()
    
    static let coversDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("SwitchRPC/covers")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    static func localPath(for urlString: String) -> URL? {
        guard !urlString.isEmpty else { return nil }
        if urlString.hasPrefix("file://") || urlString.hasPrefix("/") {
            let path = urlString.replacingOccurrences(of: "file://", with: "")
            return URL(fileURLWithPath: path)
        }
        // Pour les URLs distantes, on crée un hash de fichier local sécurisé
        let hash = String(format: "%016llx", UInt64(bitPattern: Int64(urlString.hashValue)))
        var ext = "jpg"
        if urlString.lowercased().contains(".png") { ext = "png" }
        else if urlString.lowercased().contains(".webp") { ext = "webp" }
        return coversDir.appendingPathComponent("cover_\(hash).\(ext)")
    }
    
    static func deleteLocalCover(for urlString: String) {
        guard let file = localPath(for: urlString), FileManager.default.fileExists(atPath: file.path) else { return }
        try? FileManager.default.removeItem(at: file)
        cache.removeObject(forKey: urlString as NSString)
    }
    
    static func clearAllCovers() {
        cache.removeAllObjects()
        if let files = try? FileManager.default.contentsOfDirectory(at: coversDir, includingPropertiesForKeys: nil) {
            for f in files {
                try? FileManager.default.removeItem(at: f)
            }
        }
    }
    
    static func getCoversSizeFormatted() -> String {
        guard let files = try? FileManager.default.contentsOfDirectory(at: coversDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 Ko"
        }
        var totalBytes: Int64 = 0
        for f in files {
            if let vals = try? f.resourceValues(forKeys: [.fileSizeKey]), let s = vals.fileSize {
                totalBytes += Int64(s)
            }
        }
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useAll]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: totalBytes)
    }
    
    func load(from urlString: String) {
        let clean = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            self.image = nil
            return
        }
        
        // Vérification cache mémoire
        if let cached = Self.cache.object(forKey: clean as NSString) {
            self.image = cached
            return
        }
        
        // Fichier local ou téléchargé précédemment
        if let localFile = Self.localPath(for: clean), FileManager.default.fileExists(atPath: localFile.path) {
            if let img = NSImage(contentsOf: localFile) {
                Self.cache.setObject(img, forKey: clean as NSString)
                self.image = img
                return
            }
        }
        
        // Si URL HTTP/HTTPS, on télécharge et on stocke en LOCAL
        guard let url = URL(string: clean), url.scheme == "http" || url.scheme == "https" else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let img = NSImage(data: data) else { return }
            Self.cache.setObject(img, forKey: clean as NSString)
            
            // Sauvegarde locale sur le disque
            if let dest = Self.localPath(for: clean) {
                try? data.write(to: dest, options: .atomic)
            }
            
            DispatchQueue.main.async {
                self?.image = img
            }
        }.resume()
    }
}

struct CachedAsyncImage<Placeholder: View>: View {
    @StateObject private var loader = ImageLoader()
    let url: String
    let placeholder: () -> Placeholder
    
    var body: some View {
        Group {
            if let nsImage = loader.image {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load(from: url)
        }
        .onChange(of: url) { _, newUrl in
            loader.load(from: newUrl)
        }
    }
}

// MARK: - Discord Live Preview Widget
struct DiscordCardPreview: View {
    let activityType: ActivityType
    let appName: String
    let details: String
    let state: String
    let imageUrl: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(activityType.discordHeader)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(white: 0.85))
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundColor(Color(white: 0.5))
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            
            HStack(alignment: .top, spacing: 14) {
                // Pochette
                CachedAsyncImage(url: imageUrl.isEmpty ? "https://assets.nintendo.com/image/upload/f_auto/q_auto/v1/ncom/en_US/merchandising/curated%20list/Nintendo%20Switch%20Family/switch_logo_square" : imageUrl) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.2))
                        .overlay(Image(systemName: "gamecontroller.fill").foregroundColor(Color(white: 0.5)))
                }
                .frame(width: 72, height: 72)
                .clipped()
                .cornerRadius(12)
                
                // Textes Discord
                VStack(alignment: .leading, spacing: 3) {
                    Text(appName.isEmpty ? "Titre" : appName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(details.isEmpty ? "Nom du jeu" : details)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.8))
                        .lineLimit(1)
                    
                    Text(state.isEmpty ? "En cours" : state)
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.7))
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 9))
                        Text("0:08")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Color(red: 0.25, green: 0.8, blue: 0.45))
                    .padding(.top, 1)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - GitHub Update Checker
class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    static let currentVersion = "1.1.0"
    static let repoOwner = "Jellacious"
    static let repoName = "SwitchRPC"
    
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String, releaseUrl: String)
        case error(String)
    }
    
    @Published var state: State = .idle
    
    func checkForUpdates() {
        state = .checking
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest") else {
            state = .error("URL invalide")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("SwitchRPC/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 6.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, err in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if err != nil {
                    self.state = .error(L10n.tr("Cannot reach GitHub", "Impossible de joindre GitHub"))
                    return
                }
                
                guard let http = response as? HTTPURLResponse else {
                    self.state = .error(L10n.tr("Network error", "Erreur réseau"))
                    return
                }
                
                if http.statusCode == 404 {
                    // Dépôt ou release pas encore créée
                    self.state = .upToDate
                    return
                }
                
                guard http.statusCode == 200, let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    self.state = .error(L10n.tr("Invalid release format", "Format de release inconnu"))
                    return
                }
                
                let latestTag = tagName.replacingOccurrences(of: "v", with: "").trimmingCharacters(in: .whitespaces)
                let htmlUrl = json["html_url"] as? String ?? "https://github.com/\(Self.repoOwner)/\(Self.repoName)/releases"
                
                if latestTag.compare(Self.currentVersion, options: .numeric) == .orderedDescending {
                    self.state = .updateAvailable(version: tagName, releaseUrl: htmlUrl)
                } else {
                    self.state = .upToDate
                }
            }
        }.resume()
    }
}

// MARK: - Nintendo Search Service & Model
struct NintendoGameItem: Identifiable, Hashable {
    let id: String
    let title: String
    let imageUrl: String
    let releaseDate: String?
}

class NintendoSearchService: ObservableObject {
    @Published var query: String = ""
    @Published var results: [NintendoGameItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var searchWorkItem: DispatchWorkItem?
    
    func onQueryChanged(_ newQuery: String) {
        searchWorkItem?.cancel()
        let trimmed = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            self.results = []
            self.isLoading = false
            self.errorMessage = nil
            return
        }
        
        let item = DispatchWorkItem { [weak self] in
            self?.performSearch(trimmed)
        }
        searchWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }
    
    func performSearch(_ text: String) {
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let lang = L10n.lang == .french ? "fr" : "en"
        let urlString = "https://searching.nintendo-europe.com/\(lang)/select?q=\(encoded)&fq=type:GAME%20AND%20system_type:nintendoswitch*&wt=json&rows=24"
        guard let url = URL(string: urlString) else { return }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let responseObj = json["response"] as? [String: Any],
                      let docs = responseObj["docs"] as? [[String: Any]] else {
                    self.errorMessage = L10n.tr("No results found", "Aucun résultat trouvé")
                    return
                }
                
                var items: [NintendoGameItem] = []
                for doc in docs {
                    guard let title = doc["title"] as? String else { continue }
                    let rawImage = (doc["image_url_sq_s"] as? String)
                        ?? (doc["wishlist_email_square_image_url_s"] as? String)
                        ?? (doc["image_url_h2x1_s"] as? String)
                        ?? (doc["image_url"] as? String)
                        ?? ""
                    
                    let fsId = (doc["fs_id"] as? String) ?? UUID().uuidString
                    let prettyDate = doc["pretty_date_s"] as? String
                    
                    items.append(NintendoGameItem(
                        id: fsId,
                        title: title,
                        imageUrl: rawImage,
                        releaseDate: prettyDate
                    ))
                }
                self.results = items
            }
        }.resume()
    }
}

// MARK: - Launch At Login Helper (via ~/Library/LaunchAgents)
struct LaunchAtLoginHelper {
    static let plistUrl: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("com.nino.switchrpc.plist")
    }()
    
    static func setLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            let appPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/SwitchRPC.app/Contents/MacOS/SwitchRPC").path
            let plistContent = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>com.nino.switchrpc</string>
                <key>ProgramArguments</key>
                <array>
                    <string>\(appPath)</string>
                </array>
                <key>RunAtLoad</key>
                <true/>
                <key>ProcessType</key>
                <string>Interactive</string>
            </dict>
            </plist>
            """
            try? plistContent.write(to: plistUrl, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(at: plistUrl)
        }
    }
}

// MARK: - App Settings Model
struct AppSettings: Codable {
    var launchAtLogin: Bool = false
    var enableMenuBar: Bool = true
    var language: AppLanguage = .english
}

// MARK: - Persistence Manager
class GameStore: ObservableObject {
    @Published var apps: [DiscordApp] = []
    @Published var games: [SavedGame] = []
    @Published var settings: AppSettings = AppSettings()
    
    private static let appSupportDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("SwitchRPC")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    private let appsFileUrl: URL = {
        return appSupportDir.appendingPathComponent("apps.json")
    }()
    
    private let gamesFileUrl: URL = {
        return appSupportDir.appendingPathComponent("games.json")
    }()
    
    private let settingsFileUrl: URL = {
        return appSupportDir.appendingPathComponent("settings.json")
    }()
    
    init() {
        load()
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(apps) {
            try? data.write(to: appsFileUrl, options: .atomic)
        }
        if let data = try? JSONEncoder().encode(games) {
            try? data.write(to: gamesFileUrl, options: .atomic)
        }
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: settingsFileUrl, options: .atomic)
        }
    }
    
    func updateSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
        save()
        LaunchAtLoginHelper.setLaunchAtLogin(newSettings.launchAtLogin)
        AppDelegate.shared?.updateMenuBarVisibility()
    }
    
    func load() {
        if let data = try? Data(contentsOf: settingsFileUrl),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        }
        
        var loadedApps: [DiscordApp]? = nil
        if let data = try? Data(contentsOf: appsFileUrl),
           let decoded = try? JSONDecoder().decode([DiscordApp].self, from: data) {
            loadedApps = decoded
        }
        
        var loadedGames: [SavedGame]? = nil
        if let data = try? Data(contentsOf: gamesFileUrl),
           let decoded = try? JSONDecoder().decode([SavedGame].self, from: data) {
            loadedGames = decoded
        }
        
        if let la = loadedApps, !la.isEmpty {
            self.apps = la
        } else {
            let defaultSwitch = DiscordApp(name: "Nintendo Switch", clientId: "1560034774049882124")
            self.apps = [defaultSwitch]
        }
        
        if let lg = loadedGames {
            self.games = lg
        } else {
            self.games = []
            save()
        }
    }
    
    func addApp(name: String, clientId: String) {
        let newApp = DiscordApp(name: name, clientId: clientId)
        apps.append(newApp)
        save()
    }
    
    func removeApp(_ app: DiscordApp) {
        apps.removeAll { $0.id == app.id }
        if let fallbackApp = apps.first {
            for i in 0..<games.count {
                if games[i].appId == app.id {
                    games[i].appId = fallbackApp.id
                }
            }
        }
        save()
    }
    
    func addGame(name: String, status: String, imageUrl: String, appId: UUID, activityType: ActivityType) {
        let fallback = "https://assets.nintendo.com/image/upload/f_auto/q_auto/v1/ncom/en_US/merchandising/curated%20list/Nintendo%20Switch%20Family/switch_logo_square"
        let newG = SavedGame(
            name: name,
            status: status.trimmingCharacters(in: .whitespaces).isEmpty ? "En cours" : status,
            imageUrl: imageUrl.trimmingCharacters(in: .whitespaces).isEmpty ? fallback : imageUrl,
            appId: appId,
            activityType: activityType
        )
        games.append(newG)
        save()
    }
    
    func updateGame(_ game: SavedGame) {
        if let idx = games.firstIndex(where: { $0.id == game.id }) {
            let oldGame = games[idx]
            if oldGame.imageUrl != game.imageUrl && !oldGame.imageUrl.isEmpty {
                ImageLoader.deleteLocalCover(for: oldGame.imageUrl)
            }
            var g = game
            if g.status.trimmingCharacters(in: .whitespaces).isEmpty {
                g.status = "En cours"
            }
            games[idx] = g
            save()
        }
    }
    
    func removeGame(_ game: SavedGame) {
        if !game.imageUrl.isEmpty {
            ImageLoader.deleteLocalCover(for: game.imageUrl)
        }
        games.removeAll { $0.id == game.id }
        save()
    }
    
    func getApp(for appId: UUID) -> DiscordApp? {
        return apps.first { $0.id == appId } ?? apps.first
    }
}

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
                "details": cleanDetails,
                "timestamps": ["start": startTime]
            ]
            
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

// MARK: - Global App State
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var store = GameStore()
    @Published var currentGame: SavedGame? = nil
    @Published var startTime: Int = Int(Date().timeIntervalSince1970)
    @Published var errorMessage: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }
    
    func selectGame(_ game: SavedGame) {
        if currentGame?.id == game.id {
            stop()
        } else {
            guard DiscordIPC.isDiscordAppRunning() else {
                self.currentGame = nil
                self.errorMessage = L10n.tr("Discord is not running on your Mac. Please launch Discord first.", "Discord n'est pas ouvert sur votre Mac. Veuillez lancer Discord.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    if self.errorMessage != nil { self.errorMessage = nil }
                }
                return
            }
            guard let app = store.getApp(for: game.appId) else {
                self.errorMessage = L10n.tr("Discord application title not found", "Application Discord introuvable")
                return
            }
            errorMessage = nil
            startTime = Int(Date().timeIntervalSince1970)
            
            DiscordIPC.shared.setGame(game, app: app, startTime: startTime) { [weak self] success, err in
                guard let self = self else { return }
                if success {
                    self.currentGame = game
                    self.errorMessage = nil
                } else {
                    self.currentGame = nil
                    self.errorMessage = err ?? L10n.tr("Unknown Discord error", "Erreur inconnue Discord")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                        if self.errorMessage != nil { self.errorMessage = nil }
                    }
                }
            }
        }
    }
    
    func stop() {
        currentGame = nil
        errorMessage = nil
        DiscordIPC.shared.clearActivity()
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @ObservedObject var state = AppState.shared
    @ObservedObject var store = AppState.shared.store
    @State private var showManageModal: Bool = false
    @State private var editingGame: SavedGame? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(red: 0.9, green: 0.2, blue: 0.2))
                        .frame(width: 14, height: 14)
                    Text("SwitchRPC")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                
                Spacer()
                
                if let err = state.errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(err)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red)
                            .lineLimit(1)
                        Button(action: { state.errorMessage = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(20)
                } else if let curr = state.currentGame, let app = store.getApp(for: curr.appId) {
                    HStack(spacing: 8) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("\(curr.activityType.label) \(app.name) : \(curr.name)")
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .frame(maxWidth: 280)
                        Button(L10n.tr("Stop", "Arrêter")) {
                            state.stop()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            
            Divider().opacity(0.4)
            
            // Grid of Game Tiles
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(store.games) { game in
                        let app = store.getApp(for: game.appId)
                        GameCard(
                            game: game,
                            appName: app?.name ?? L10n.tr("Unknown", "Inconnu"),
                            isSelected: state.currentGame?.id == game.id,
                            onPlay: { state.selectGame(game) },
                            onEdit: { editingGame = game },
                            onDelete: { store.removeGame(game) }
                        )
                    }
                    
                    // Add Card
                    Button(action: { showManageModal = true }) {
                        VStack(alignment: .leading, spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.primary.opacity(0.05))
                                    .frame(width: 160, height: 160)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                            .foregroundColor(.secondary.opacity(0.4))
                                    )
                                Image(systemName: "plus")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(store.games.isEmpty ? L10n.tr("Add your first game", "Ajouter un jeu") : L10n.tr("Add / Manage", "Ajouter / Gérer"))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .frame(width: 160, alignment: .leading)
                                Text(L10n.tr("New game or title", "Nouveau jeu ou titre"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .frame(width: 160, alignment: .leading)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .frame(height: 275)
            
            Divider().opacity(0.4)
            
            // Footer Info
            HStack {
                Text(store.games.isEmpty ? L10n.tr("Click '+' to add your first game cover", "Cliquez sur '+' pour ajouter votre première jaquette") : L10n.tr("Click a cover to launch • Pencil icon to edit", "Clique sur une pochette pour lancer • Icône crayon pour modifier"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(store.games.count) \(L10n.tr("games", "jeux")) • \(store.apps.count) \(L10n.tr("apps", "titres"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(width: 800, height: 415)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showManageModal) {
            ManageSheet(store: store, isPresented: $showManageModal)
        }
        .sheet(item: $editingGame) { game in
            EditGameSheet(game: game, store: store, onDone: { updated in
                store.updateGame(updated)
                if state.currentGame?.id == updated.id {
                    state.selectGame(updated)
                }
                editingGame = nil
            }, onCancel: {
                editingGame = nil
            })
        }
    }
}

// MARK: - Game Card View
struct GameCard: View {
    let game: SavedGame
    let appName: String
    let isSelected: Bool
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered: Bool = false
    @State private var confirmDelete: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: game.imageUrl) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(Image(systemName: "gamecontroller").font(.system(size: 30)).foregroundColor(.secondary))
                }
                .frame(width: 160, height: 160)
                .clipped()
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color(red: 0.2, green: 0.8, blue: 0.3) : (isHovered ? Color.accentColor : Color.clear), lineWidth: 3.5)
                )
                .shadow(color: isSelected ? Color.green.opacity(0.3) : Color.black.opacity(0.12), radius: isSelected ? 8 : 4, y: 3)
                
                if isSelected {
                    Text(L10n.tr("PLAYING", "EN COURS"))
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green)
                        .cornerRadius(6)
                        .padding(8)
                } else if isHovered {
                    HStack(spacing: 6) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.65))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            if confirmDelete {
                                onDelete()
                            } else {
                                confirmDelete = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                    confirmDelete = false
                                }
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: confirmDelete ? "exclamationmark.triangle.fill" : "trash.fill")
                                    .font(.system(size: 11))
                                if confirmDelete {
                                    Text(L10n.tr("Delete?", "Supprimer ?"))
                                        .font(.system(size: 10, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, confirmDelete ? 8 : 6)
                            .padding(.vertical, 6)
                            .background(confirmDelete ? Color.red : Color.black.opacity(0.65))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(6)
                    .animation(.easeInOut(duration: 0.2), value: confirmDelete)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onPlay() }
            .onHover { 
                isHovered = $0
                if !$0 { confirmDelete = false }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(game.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .frame(width: 160, alignment: .leading)
                
                HStack(spacing: 4) {
                    Text(game.activityType.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(appName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentColor)
                }
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)
                
                Text(game.status.isEmpty ? L10n.tr("Playing", "En cours") : game.status)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 160, alignment: .leading)
            }
        }
    }
}

// MARK: - Edit Game Modal Sheet
struct EditGameSheet: View {
    let game: SavedGame
    @ObservedObject var store: GameStore
    let onDone: (SavedGame) -> Void
    let onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var status: String = ""
    @State private var imageUrl: String = ""
    @State private var appId: UUID = UUID()
    @State private var activityType: ActivityType = .playing
    @State private var showSearchSheet: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text(L10n.tr("Edit Game", "Modifier le jeu"))
                .font(.headline)
            
            // Bouton de recherche au-dessus de la preview
            HStack {
                Spacer()
                Button(action: { showSearchSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11, weight: .bold))
                        Text(L10n.tr("Search game", "Rechercher un jeu"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, -6)
            
            // Live Preview Card
            let selectedAppName = store.getApp(for: appId)?.name ?? L10n.tr("Title", "Titre")
            DiscordCardPreview(
                activityType: activityType,
                appName: selectedAppName,
                details: name,
                state: status,
                imageUrl: imageUrl
            )
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("Activity type:", "Type d'action :")).font(.caption).foregroundColor(.secondary)
                    Picker("", selection: $activityType) {
                        ForEach(ActivityType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("Title (Discord App):", "Titre (Application Discord) :")).font(.caption).foregroundColor(.secondary)
                    Picker("", selection: $appId) {
                        ForEach(store.apps) { app in
                            Text(app.name).tag(app.id)
                        }
                    }
                    .labelsHidden()
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("Game / Media name:", "Nom du jeu / média :")).font(.caption).foregroundColor(.secondary)
                TextField(L10n.tr("Name", "Nom"), text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L10n.tr("Description / Status:", "Description / Statut :")).font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("\(status.count)/128")
                        .font(.caption2)
                        .foregroundColor(status.count > 128 ? .red : .secondary)
                }
                TextField(L10n.tr("Description", "Description"), text: $status)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("Cover Image URL:", "Lien de la jaquette (Image URL) :")).font(.caption).foregroundColor(.secondary)
                TextField("https://...", text: $imageUrl)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack(spacing: 12) {
                Button(L10n.tr("Cancel", "Annuler"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.tr("Save changes", "Enregistrer les modifications")) {
                    var updated = game
                    updated.name = name
                    updated.status = status
                    updated.imageUrl = imageUrl
                    updated.appId = appId
                    updated.activityType = activityType
                    onDone(updated)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 480)
        .sheet(isPresented: $showSearchSheet) {
            GameSearchSheet(isPresented: $showSearchSheet) { selectedGame in
                self.name = selectedGame.title
                self.imageUrl = selectedGame.imageUrl
            }
        }
        .onAppear {
            name = game.name
            status = game.status
            imageUrl = game.imageUrl
            appId = game.appId
            activityType = game.activityType
        }
    }
}

// MARK: - Game Search Sheet (Nintendo Database)
struct GameSearchSheet: View {
    @Binding var isPresented: Bool
    let onSelect: (NintendoGameItem) -> Void
    
    @StateObject private var searcher = NintendoSearchService()
    @State private var hoveredItemId: String? = nil
    
    var body: some View {
        VStack(spacing: 14) {
            // Header with search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 15))
                
                TextField(L10n.tr("Search game (e.g. Mario, Zelda...)", "Rechercher un jeu (ex: Mario, Zelda...)"), text: $searcher.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onChange(of: searcher.query) { _, newQuery in
                        searcher.onQueryChanged(newQuery)
                    }
                
                if !searcher.query.isEmpty {
                    Button(action: {
                        searcher.query = ""
                        searcher.results = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                if searcher.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                }
                
                Button(L10n.tr("Close", "Fermer")) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(10)
            
            // Results list or Empty State
            if searcher.results.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 38))
                        .foregroundColor(.secondary.opacity(0.4))
                    
                    if searcher.query.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(L10n.tr("Type a game name to search Nintendo catalog", "Tapez un nom de jeu pour explorer le catalogue"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    } else if !searcher.isLoading {
                        Text(L10n.tr("No games found for this search", "Aucun jeu trouvé pour cette recherche"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(searcher.results) { item in
                            Button(action: {
                                onSelect(item)
                                isPresented = false
                            }) {
                                HStack(spacing: 12) {
                                    CachedAsyncImage(url: item.imageUrl) {
                                        ZStack {
                                            Color.primary.opacity(0.08)
                                            Image(systemName: "gamecontroller")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 52, height: 52)
                                    .cornerRadius(8)
                                    .clipped()
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        if let date = item.releaseDate, !date.isEmpty {
                                            Text(date)
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(hoveredItemId == item.id ? Color.accentColor : Color.secondary.opacity(0.5))
                                }
                                .padding(8)
                                .background(hoveredItemId == item.id ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .onHover { isHover in
                                if isHover {
                                    hoveredItemId = item.id
                                } else if hoveredItemId == item.id {
                                    hoveredItemId = nil
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(18)
        .frame(width: 500, height: 440)
    }
}

// MARK: - Modal Sheet avec les deux onglets ("Jeu" et "Titres")
struct ManageSheet: View {
    @ObservedObject var store: GameStore
    @Binding var isPresented: Bool
    @State private var selectedTab: Int = 0
    
    // Onglet 1 : Nouveau Jeu
    @State private var gameName: String = ""
    @State private var gameStatus: String = "En cours"
    @State private var gameImageUrl: String = ""
    @State private var selectedAppId: UUID = UUID()
    @State private var activityType: ActivityType = .playing
    @State private var showSearchSheet: Bool = false
    
    // Onglet 2 : Nouveau Titre
    @State private var appName: String = ""
    @State private var appClientId: String = ""
    
    // Onglet 3 : Réglages & Mises à jour
    @StateObject private var updater = UpdateChecker.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Picker("", selection: $selectedTab) {
                Text(L10n.tr("Add Game", "Ajouter un Jeu")).tag(0)
                Text(L10n.tr("Discord Apps", "Gérer les Titres")).tag(1)
                Text(L10n.tr("Settings", "Réglages")).tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.top, 2)
            
            if selectedTab == 0 {
                // ONGLET 1 : NOUVEAU JEU AVEC PREVIEW EN DIRECT
                let selectedApp = store.getApp(for: selectedAppId)?.name ?? L10n.tr("Title", "Titre")
                
                // Bouton de recherche au-dessus de la preview
                HStack {
                    Spacer()
                    Button(action: { showSearchSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .bold))
                            Text(L10n.tr("Search game", "Rechercher un jeu"))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, -6)
                
                // Live Discord Preview Card
                DiscordCardPreview(
                    activityType: activityType,
                    appName: selectedApp,
                    details: gameName,
                    state: gameStatus,
                    imageUrl: gameImageUrl
                )
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.tr("Activity type:", "Type d'action :")).font(.caption).foregroundColor(.secondary)
                            Picker("", selection: $activityType) {
                                ForEach(ActivityType.allCases) { type in
                                    Text(type.label).tag(type)
                                }
                            }
                            .labelsHidden()
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.tr("Title (Discord App):", "Titre (App Discord) :")).font(.caption).foregroundColor(.secondary)
                            if store.apps.isEmpty {
                                Text(L10n.tr("⚠️ Create an app title first", "⚠️ Créez un titre d'abord")).font(.caption).foregroundColor(.red)
                            } else {
                                Picker("", selection: $selectedAppId) {
                                    ForEach(store.apps) { app in
                                        Text(app.name).tag(app.id)
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.tr("Game / Media name:", "Nom du jeu / média :")).font(.caption).foregroundColor(.secondary)
                        TextField(L10n.tr("e.g. Super Mario Odyssey", "Ex: Super Mario Odyssey"), text: $gameName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(L10n.tr("Description / Status:", "Description / Statut :")).font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("\(gameStatus.count)/128")
                                .font(.caption2)
                                .foregroundColor(gameStatus.count > 128 ? .red : .secondary)
                        }
                        TextField(L10n.tr("e.g. In Mushroom Kingdom", "Ex: Royaume Champignon"), text: $gameStatus)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.tr("Cover Image URL:", "Lien de la jaquette (Image URL) :")).font(.caption).foregroundColor(.secondary)
                        TextField("https://...", text: $gameImageUrl)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .onAppear {
                    if let first = store.apps.first {
                        selectedAppId = first.id
                    }
                }
                
                Spacer(minLength: 0)
                
                HStack {
                    Button(L10n.tr("Close", "Fermer")) { isPresented = false }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button(L10n.tr("Add", "Ajouter")) {
                        if !gameName.trimmingCharacters(in: .whitespaces).isEmpty {
                            store.addGame(
                                name: gameName,
                                status: gameStatus,
                                imageUrl: gameImageUrl,
                                appId: selectedAppId,
                                activityType: activityType
                            )
                            isPresented = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(gameName.trimmingCharacters(in: .whitespaces).isEmpty || store.apps.isEmpty)
                }
            } else if selectedTab == 1 {
                // ONGLET 2 : GÉRER LES TITRES
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(L10n.tr("Registered Discord Apps:", "Titres enregistrés :"))
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            if let url = URL(string: "https://discord.com/developers/applications") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                Text(L10n.tr("Open Discord Developer Portal", "Ouvrir Discord Developer Portal"))
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    List {
                        ForEach(store.apps) { app in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(app.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Client ID: \(app.clientId)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if store.apps.count > 1 {
                                    Button(action: { store.removeApp(app) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .cornerRadius(10)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.tr("Add a new title:", "Ajouter un nouveau titre :"))
                            .font(.caption).foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            TextField(L10n.tr("Name (e.g. Steam, Plex...)", "Nom (ex: Steam, Plex...)"), text: $appName)
                                .textFieldStyle(.roundedBorder)
                            TextField("Discord Client ID", text: $appClientId)
                                .textFieldStyle(.roundedBorder)
                            Button(L10n.tr("Add", "Ajouter")) {
                                if !appName.trimmingCharacters(in: .whitespaces).isEmpty &&
                                   !appClientId.trimmingCharacters(in: .whitespaces).isEmpty {
                                    store.addApp(name: appName, clientId: appClientId.trimmingCharacters(in: .whitespaces))
                                    appName = ""
                                    appClientId = ""
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(appName.trimmingCharacters(in: .whitespaces).isEmpty || appClientId.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    HStack {
                        Spacer()
                        Button(L10n.tr("Done", "Terminé")) { isPresented = false }
                            .keyboardShortcut(.defaultAction)
                    }
                }
            } else {
                // ONGLET 3 : RÉGLAGES DE L'APPLICATION
                VStack(alignment: .leading, spacing: 14) {
                    // SÉLECTEUR DE LANGUE
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.tr("Language", "Langue"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                            Picker("", selection: Binding(
                                get: { store.settings.language },
                                set: { newLang in
                                    var s = store.settings
                                    s.language = newLang
                                    store.updateSettings(s)
                                }
                            )) {
                                ForEach(AppLanguage.allCases) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 130)
                        }
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.tr("System Behavior", "Comportement système"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Toggle(isOn: Binding(
                            get: { store.settings.launchAtLogin },
                            set: { val in
                                var s = store.settings
                                s.launchAtLogin = val
                                store.updateSettings(s)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Launch at Mac startup", "Lancer au démarrage du Mac"))
                                    .font(.system(size: 13, weight: .medium))
                                Text(L10n.tr("Automatically starts SwitchRPC when you log in.", "Démarre automatiquement SwitchRPC à la connexion de session."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        
                        Divider()
                        
                        Toggle(isOn: Binding(
                            get: { store.settings.enableMenuBar },
                            set: { val in
                                var s = store.settings
                                s.enableMenuBar = val
                                store.updateSettings(s)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Show in Menu Bar", "Afficher dans la barre des menus"))
                                    .font(.system(size: 13, weight: .medium))
                                Text(L10n.tr("Keeps a status icon in the menu bar. If disabled, closing the window quits the app.", "Ajoute un menu d'état en haut de l'écran. Si désactivé, fermer la fenêtre quittera l'application."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.tr("Storage & Local Cache", "Stockage & Cache local"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.tr("Cover images cached locally:", "Jaquettes en cache sur le disque :"))
                                    .font(.system(size: 12))
                                Text(ImageLoader.getCoversSizeFormatted())
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(L10n.tr("Clear Cache", "Vider le cache")) {
                                ImageLoader.clearAllCovers()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(12)
                    
                    // SECTION MISES À JOUR GITHUB
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.tr("Updates", "Mises à jour"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SwitchRPC v\(UpdateChecker.currentVersion)")
                                    .font(.system(size: 12, weight: .semibold))
                                
                                switch updater.state {
                                case .idle:
                                    Text("GitHub: Jellacious/SwitchRPC")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                case .checking:
                                    HStack(spacing: 4) {
                                        ProgressView().scaleEffect(0.6)
                                        Text(L10n.tr("Checking for updates...", "Recherche en cours..."))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                case .upToDate:
                                    Text(L10n.tr("✓ You are up to date", "✓ Vous utilisez la dernière version"))
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                case .updateAvailable(let version, _):
                                    Text(L10n.tr("🎉 New version available: \(version)", "🎉 Nouvelle version disponible : \(version)"))
                                        .font(.caption2)
                                        .foregroundColor(.accentColor)
                                case .error(let msg):
                                    Text("⚠️ \(msg)")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Spacer()
                            
                            if case .updateAvailable(_, let releaseUrl) = updater.state {
                                Button(L10n.tr("Download", "Télécharger")) {
                                    if let url = URL(string: releaseUrl) {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            } else {
                                Button(action: {
                                    updater.checkForUpdates()
                                }) {
                                    Text(L10n.tr("Check", "Vérifier"))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(updater.state == .checking)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 0)
                    
                    HStack {
                        Spacer()
                        Button(L10n.tr("Close", "Fermer")) { isPresented = false }
                            .keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 500, height: 535)
        .sheet(isPresented: $showSearchSheet) {
            GameSearchSheet(isPresented: $showSearchSheet) { selectedGame in
                self.gameName = selectedGame.title
                self.gameImageUrl = selectedGame.imageUrl
            }
        }
    }
}

// MARK: - App Delegate & Standard Edit Menu Setup
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    static weak var shared: AppDelegate?
    var window: NSWindow!
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.regular)
        if let icon = Bundle.main.image(forResource: "AppIcon") {
            NSApp.applicationIconImage = icon
        }
        setupMainMenu()
        updateMenuBarVisibility()
        
        createAndShowWindow()
    }
    
    func updateMenuBarVisibility() {
        let enabled = AppState.shared.store.settings.enableMenuBar
        if enabled {
            if statusItem == nil {
                setupStatusBar()
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }
    
    func createAndShowWindow() {
        if window == nil {
            let contentView = ContentView()
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 415),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.isReleasedWhenClosed = false
            win.center()
            win.title = "SwitchRPC"
            win.contentView = NSHostingView(rootView: contentView)
            win.delegate = self
            self.window = win
        }
        
        NSApp.setActivationPolicy(.regular)
        setupMainMenu()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        if AppState.shared.store.settings.enableMenuBar {
            // Dès qu'on ferme la fenêtre avec Menu Bar activée : reste discret dans la barre des menus
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
            }
        } else {
            // Si la Menu Bar est désactivée : fermer la fenêtre quitte totalement l'application !
            AppState.shared.stop()
            NSApp.terminate(nil)
        }
    }
    
    func setupStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: "SwitchRPC")
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        self.statusItem = item
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let state = AppState.shared
        
        // Statut actuel
        if let current = state.currentGame, let app = state.store.getApp(for: current.appId) {
            let activeItem = NSMenuItem(title: "🟢 \(app.name) : \(current.name)", action: nil, keyEquivalent: "")
            activeItem.isEnabled = false
            menu.addItem(activeItem)
            
            let stopItem = NSMenuItem(title: L10n.tr("Stop Discord Presence", "Arrêter la présence Discord"), action: #selector(menuStopActivity), keyEquivalent: "s")
            stopItem.target = self
            menu.addItem(stopItem)
        } else {
            let idleItem = NSMenuItem(title: L10n.tr("⚪ Idle (No game active)", "⚪ Inactif (Aucun jeu lancé)"), action: nil, keyEquivalent: "")
            idleItem.isEnabled = false
            menu.addItem(idleItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Sous-menu Lancer un jeu
        let gamesMenu = NSMenu()
        for game in state.store.games {
            let isCurrent = state.currentGame?.id == game.id
            let title = (isCurrent ? "✓ " : "") + game.name
            let item = NSMenuItem(title: title, action: #selector(menuSelectGame(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = game
            gamesMenu.addItem(item)
        }
        
        let playSubmenuItem = NSMenuItem(title: L10n.tr("Switch Game...", "Changer de jeu..."), action: nil, keyEquivalent: "")
        playSubmenuItem.submenu = gamesMenu
        menu.addItem(playSubmenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let showWindowItem = NSMenuItem(title: L10n.tr("Open Switch Window", "Ouvrir la fenêtre Switch"), action: #selector(menuShowWindow), keyEquivalent: "o")
        showWindowItem.target = self
        menu.addItem(showWindowItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: L10n.tr("Quit SwitchRPC", "Quitter SwitchRPC"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }
    
    @objc func menuStopActivity() {
        AppState.shared.stop()
    }
    
    @objc func menuSelectGame(_ sender: NSMenuItem) {
        if let game = sender.representedObject as? SavedGame {
            AppState.shared.selectGame(game)
        }
    }
    
    @objc func menuShowWindow() {
        createAndShowWindow()
    }
    
    func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // Menu Application
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L10n.tr("Quit SwitchRPC", "Quitter SwitchRPC"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        
        // Menu Fichier (avec Commande + W pour fermer la fenêtre)
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: L10n.tr("File", "Fichier"))
        let closeItem = NSMenuItem(title: L10n.tr("Close Window", "Fermer la fenêtre"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(closeItem)
        fileMenuItem.submenu = fileMenu
        
        // Menu Édition (Cmd+X, Cmd+C, Cmd+V, Cmd+A)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: L10n.tr("Edit", "Édition"))
        editMenu.addItem(withTitle: L10n.tr("Cut", "Couper"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n.tr("Copy", "Copier"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.tr("Paste", "Coller"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n.tr("Select All", "Tout sélectionner"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        
        NSApp.mainMenu = mainMenu
    }
    
    // Déclenché quand on relance l'app depuis le Finder, Spotlight, Vorssaint ou le Dock
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        createAndShowWindow()
        return true
    }
    
    func application(_ application: NSApplication, openFiles filenames: [String]) {
        createAndShowWindow()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        DiscordIPC.shared.disconnect()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Reste actif en Menu Bar même si la fenêtre principale est fermée !
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
