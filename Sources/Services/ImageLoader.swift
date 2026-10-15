import Foundation
import SwiftUI
import AppKit

// MARK: - Image Memory & Local Disk Storage
class ImageLoader: ObservableObject {
    @Published var image: NSImage?
    private static let cache = NSCache<NSString, NSImage>()
    
    static let coversDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("SwitchRPC/covers")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    static func localPath(for urlString: String) -> URL? {
        guard !urlString.isEmpty else { return nil }
        if urlString.hasPrefix("file://") || urlString.hasPrefix("/") {
            let path = urlString.replacingOccurrences(of: "file://", with: "")
            return URL(fileURLWithPath: path)
        }
        // Pour les URLs distantes, on crée un hash de fichier local sécurisé
        let hash = String(format: "%016llx", UInt64(bitPattern: Int64(urlString.hashValue)))
        var ext = "jpg"
        if urlString.lowercased().contains(".png") { ext = "png" }
        else if urlString.lowercased().contains(".webp") { ext = "webp" }
        return coversDir.appendingPathComponent("cover_\(hash).\(ext)")
    }
    
    static func deleteLocalCover(for urlString: String) {
        guard let file = localPath(for: urlString), FileManager.default.fileExists(atPath: file.path) else { return }
        try? FileManager.default.removeItem(at: file)
        cache.removeObject(forKey: urlString as NSString)
    }
    
    static func clearAllCovers() {
        cache.removeAllObjects()
        if let files = try? FileManager.default.contentsOfDirectory(at: coversDir, includingPropertiesForKeys: nil) {
            for f in files {
                try? FileManager.default.removeItem(at: f)
            }
        }
    }
    
    static func getCoversSizeFormatted() -> String {
        guard let files = try? FileManager.default.contentsOfDirectory(at: coversDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "0 Ko"
        }
        var totalBytes: Int64 = 0
        for f in files {
            if let vals = try? f.resourceValues(forKeys: [.fileSizeKey]), let s = vals.fileSize {
                totalBytes += Int64(s)
            }
        }
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useAll]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: totalBytes)
    }
    
    func load(from urlString: String) {
        let clean = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            self.image = nil
            return
        }
        
        // Vérification cache mémoire
        if let cached = Self.cache.object(forKey: clean as NSString) {
            self.image = cached
            return
        }
        
        // Fichier local ou téléchargé précédemment
        if let localFile = Self.localPath(for: clean), FileManager.default.fileExists(atPath: localFile.path) {
            if let img = NSImage(contentsOf: localFile) {
                Self.cache.setObject(img, forKey: clean as NSString)
                self.image = img
                return
            }
        }
        
        // Si URL HTTP/HTTPS, on télécharge et on stocke en LOCAL
        guard let url = URL(string: clean), url.scheme == "http" || url.scheme == "https" else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let img = NSImage(data: data) else { return }
            Self.cache.setObject(img, forKey: clean as NSString)
            
            // Sauvegarde locale sur le disque
            if let dest = Self.localPath(for: clean) {
                try? data.write(to: dest, options: .atomic)
            }
            
            DispatchQueue.main.async {
                self?.image = img
            }
        }.resume()
    }
}

struct CachedAsyncImage<Placeholder: View>: View {
    @StateObject private var loader = ImageLoader()
    let url: String
    let placeholder: () -> Placeholder
    
    var body: some View {
        Group {
            if let nsImage = loader.image {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load(from: url)
        }
        .onChange(of: url) { _, newUrl in
            loader.load(from: newUrl)
        }
    }
}
