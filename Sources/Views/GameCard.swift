import Foundation
import SwiftUI

// MARK: - Game Card View
struct GameCard: View {
    let game: SavedGame
    let appName: String
    let isSelected: Bool
    var isDragged: Bool = false
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
                .opacity(isDragged ? 0.35 : 1.0)
                
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
