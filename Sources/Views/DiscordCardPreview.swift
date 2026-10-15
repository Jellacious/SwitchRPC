import Foundation
import SwiftUI

// MARK: - Discord Live Preview Widget
struct DiscordCardPreview: View {
    let activityType: ActivityType
    let appName: String
    let details: String
    let state: String
    let imageUrl: String
    var showElapsedTime: Bool = true
    
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
                    
                    if showElapsedTime {
                        HStack(spacing: 4) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 9))
                            Text("0:08")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(red: 0.25, green: 0.8, blue: 0.45))
                        .padding(.top, 1)
                    }
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
