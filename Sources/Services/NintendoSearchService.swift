import Foundation

// MARK: - Nintendo Search Service & Model
struct NintendoGameItem: Identifiable, Hashable {
    let id: String
    let title: String
    let imageUrl: String
    let releaseDate: String?
}

class NintendoSearchService: ObservableObject {
    @Published var query: String = ""
    @Published var results: [NintendoGameItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var searchWorkItem: DispatchWorkItem?
    
    func onQueryChanged(_ newQuery: String) {
        searchWorkItem?.cancel()
        let trimmed = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            self.results = []
            self.isLoading = false
            self.errorMessage = nil
            return
        }
        
        let item = DispatchWorkItem { [weak self] in
            self?.performSearch(trimmed)
        }
        searchWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }
    
    func performSearch(_ text: String) {
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let lang = L10n.lang == .french ? "fr" : "en"
        let urlString = "https://searching.nintendo-europe.com/\(lang)/select?q=\(encoded)&fq=type:GAME%20AND%20system_type:nintendoswitch*&wt=json&rows=24"
        guard let url = URL(string: urlString) else { return }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let responseObj = json["response"] as? [String: Any],
                      let docs = responseObj["docs"] as? [[String: Any]] else {
                    self.errorMessage = L10n.tr("No results found", "Aucun résultat trouvé")
                    return
                }
                
                var items: [NintendoGameItem] = []
                for doc in docs {
                    guard let title = doc["title"] as? String else { continue }
                    let rawImage = (doc["image_url_sq_s"] as? String)
                        ?? (doc["wishlist_email_square_image_url_s"] as? String)
                        ?? (doc["image_url_h2x1_s"] as? String)
                        ?? (doc["image_url"] as? String)
                        ?? ""
                    
                    let fsId = (doc["fs_id"] as? String) ?? UUID().uuidString
                    let prettyDate = doc["pretty_date_s"] as? String
                    
                    items.append(NintendoGameItem(
                        id: fsId,
                        title: title,
                        imageUrl: rawImage,
                        releaseDate: prettyDate
                    ))
                }
                self.results = items
            }
        }.resume()
    }
}
