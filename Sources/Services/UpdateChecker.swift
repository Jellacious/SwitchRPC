import Foundation

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
