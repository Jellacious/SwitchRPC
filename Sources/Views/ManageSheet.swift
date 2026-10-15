import Foundation
import SwiftUI
import AppKit

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
                    imageUrl: gameImageUrl,
                    showElapsedTime: store.settings.showElapsedTime
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
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 14) {
                            // APPARENCE & THÈME
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(L10n.tr("Theme", "Thème"))
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.primary)
                                        Text(L10n.tr("Switch between Light, Dark or System theme", "Choisissez le thème Clair, Sombre ou Automatique"))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { store.settings.theme },
                                        set: { newTheme in
                                            var s = store.settings
                                            s.theme = newTheme
                                            store.updateSettings(s)
                                        }
                                    )) {
                                        ForEach(AppTheme.allCases) { th in
                                            Text(th.displayName).tag(th)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(width: 150)
                                }
                            }
                            .padding(12)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(12)
                            
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
                                    .frame(width: 150)
                                }
                            }
                            .padding(12)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text(L10n.tr("System & Discord Behavior", "Comportement système & Discord"))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Toggle(isOn: Binding(
                                    get: { store.settings.showElapsedTime },
                                    set: { val in
                                        var s = store.settings
                                        s.showElapsedTime = val
                                        store.updateSettings(s)
                                        if let curr = AppState.shared.currentGame {
                                            AppState.shared.selectGame(curr)
                                        }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(L10n.tr("Show elapsed time on Discord", "Afficher le temps écoulé sur Discord"))
                                            .font(.system(size: 13, weight: .medium))
                                        Text(L10n.tr("Displays the elapsed playing timer (e.g. 01:23 elapsed) on your Discord profile.", "Affiche le chronomètre de session écoulée (ex : 01:23 écoulé) sur votre profil Discord."))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .toggleStyle(.checkbox)
                                
                                Divider()
                                
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
                        }
                        .padding(.trailing, 2)
                    }
                    
                    HStack {
                        Spacer()
                        Button(L10n.tr("Close", "Fermer")) { isPresented = false }
                            .keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 520, height: 640)
        .sheet(isPresented: $showSearchSheet) {
            GameSearchSheet(isPresented: $showSearchSheet) { selectedGame in
                self.gameName = selectedGame.title
                self.gameImageUrl = selectedGame.imageUrl
            }
        }
    }
}
