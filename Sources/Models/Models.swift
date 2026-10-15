import Foundation
import SwiftUI

// MARK: - App Theme (Default: Auto)
enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case auto = "auto"
    case dark = "dark"
    case light = "light"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .auto: return L10n.tr("Auto", "Automatique")
        case .dark: return L10n.tr("Dark", "Sombre")
        case .light: return L10n.tr("Light", "Clair")
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

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

// MARK: - App Settings Model
struct AppSettings: Codable {
    var launchAtLogin: Bool = false
    var enableMenuBar: Bool = true
    var language: AppLanguage = .english
    var theme: AppTheme = .auto
    var showElapsedTime: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case launchAtLogin, enableMenuBar, language, theme, showElapsedTime
    }
    
    init(launchAtLogin: Bool = false, enableMenuBar: Bool = true, language: AppLanguage = .english, theme: AppTheme = .auto, showElapsedTime: Bool = true) {
        self.launchAtLogin = launchAtLogin
        self.enableMenuBar = enableMenuBar
        self.language = language
        self.theme = theme
        self.showElapsedTime = showElapsedTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchAtLogin = (try? container.decode(Bool.self, forKey: .launchAtLogin)) ?? false
        enableMenuBar = (try? container.decode(Bool.self, forKey: .enableMenuBar)) ?? true
        language = (try? container.decode(AppLanguage.self, forKey: .language)) ?? .english
        theme = (try? container.decode(AppTheme.self, forKey: .theme)) ?? .auto
        showElapsedTime = (try? container.decode(Bool.self, forKey: .showElapsedTime)) ?? true
    }
}
