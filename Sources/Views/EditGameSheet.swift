import Foundation
import SwiftUI

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
                imageUrl: imageUrl,
                showElapsedTime: store.settings.showElapsedTime
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
