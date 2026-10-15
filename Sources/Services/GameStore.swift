import Foundation

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
        
        let defaultApps = [
            DiscordApp(name: "Nintendo Switch", clientId: "1560034774049882124"),
            DiscordApp(name: "PlayStation", clientId: "1560228884736118806"),
            DiscordApp(name: "Xbox", clientId: "1560229095256752171")
        ]
        
        if var la = loadedApps, !la.isEmpty {
            // S'assure que PlayStation et Xbox sont disponibles s'ils n'ont pas été ajoutés
            for def in defaultApps {
                if !la.contains(where: { $0.clientId == def.clientId }) {
                    la.append(def)
                }
            }
            self.apps = la
        } else {
            self.apps = defaultApps
            save()
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
    
    func moveGame(from sourceId: UUID, to destinationId: UUID) {
        guard sourceId != destinationId,
              let fromIndex = games.firstIndex(where: { $0.id == sourceId }),
              let toIndex = games.firstIndex(where: { $0.id == destinationId }) else { return }
        
        let moved = games.remove(at: fromIndex)
        games.insert(moved, at: toIndex)
        save()
    }
    
    func getApp(for appId: UUID) -> DiscordApp? {
        return apps.first { $0.id == appId } ?? apps.first
    }
}
