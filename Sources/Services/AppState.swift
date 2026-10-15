import Foundation
import Combine

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
