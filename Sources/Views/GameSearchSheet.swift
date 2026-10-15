import Foundation
import SwiftUI

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
