import Foundation
import SwiftUI
import AppKit

// MARK: - Main Content View
struct ContentView: View {
    @ObservedObject var state = AppState.shared
    @ObservedObject var store = AppState.shared.store
    @State private var showManageModal: Bool = false
    @State private var editingGame: SavedGame? = nil
    
    // Drag and Drop interactif
    @State private var draggedGame: SavedGame? = nil
    @State private var dragTranslation: CGFloat = 0
    @State private var dragInitialIndex: Int? = nil
    
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
                        let isCurrentDragged = draggedGame?.id == game.id
                        
                        GameCard(
                            game: game,
                            appName: app?.name ?? L10n.tr("Unknown", "Inconnu"),
                            isSelected: state.currentGame?.id == game.id,
                            isDragged: isCurrentDragged,
                            onPlay: {
                                if draggedGame == nil {
                                    state.selectGame(game)
                                }
                            },
                            onEdit: { editingGame = game },
                            onDelete: { store.removeGame(game) }
                        )
                        .offset(x: isCurrentDragged ? dragTranslation : 0)
                        .scaleEffect(isCurrentDragged ? 1.06 : 1.0)
                        .shadow(color: isCurrentDragged ? Color.black.opacity(0.35) : Color.clear, radius: isCurrentDragged ? 14 : 0, y: isCurrentDragged ? 8 : 0)
                        .zIndex(isCurrentDragged ? 999 : 1)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 8)
                                .onChanged { value in
                                    if draggedGame == nil {
                                        draggedGame = game
                                        dragInitialIndex = store.games.firstIndex(where: { $0.id == game.id })
                                    }
                                    dragTranslation = value.translation.width
                                    
                                    // Calcul dynamique des échanges pendant le glisser
                                    guard let currentIndex = store.games.firstIndex(where: { $0.id == game.id }) else { return }
                                    let cardWidthWithSpacing: CGFloat = 180 // 160 width + 20 spacing
                                    let step = Int(round(dragTranslation / cardWidthWithSpacing))
                                    let targetIndex = max(0, min(currentIndex + step, store.games.count - 1))
                                    
                                    if targetIndex != currentIndex {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            store.games.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: targetIndex > currentIndex ? targetIndex + 1 : targetIndex)
                                            dragTranslation -= CGFloat(targetIndex - currentIndex) * cardWidthWithSpacing
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        dragTranslation = 0
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        draggedGame = nil
                                        dragInitialIndex = nil
                                        store.save()
                                    }
                                }
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
                Text(store.games.isEmpty ? L10n.tr("Click '+' to add your first game cover", "Cliquez sur '+' pour ajouter votre première jaquette") : L10n.tr("Drag to reorder • Click to launch • Pencil to edit", "Glisser-déposer pour réorganiser • Cliquer pour lancer • Crayon pour modifier"))
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
        .preferredColorScheme(store.settings.theme.colorScheme)
        .sheet(isPresented: $showManageModal) {
            ManageSheet(store: store, isPresented: $showManageModal)
                .preferredColorScheme(store.settings.theme.colorScheme)
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
            .preferredColorScheme(store.settings.theme.colorScheme)
        }
    }
}
