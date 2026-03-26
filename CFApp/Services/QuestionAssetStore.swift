import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Stocke les images importees sur disque (Application Support).
final class QuestionAssetStore {
    static let shared = QuestionAssetStore()
    private let cache = NSCache<NSString, PlatformImage>()
    private let ioQueue = DispatchQueue(label: "cfaquiz.questionAssetStore", qos: .utility)

    private init() {}

    private var assetsDir: URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("CFAQuizApp", isDirectory: true)
        if !fm.fileExists(atPath: appDir.path) {
            try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        let assets = appDir.appendingPathComponent("ImportedAssets", isDirectory: true)
        if !fm.fileExists(atPath: assets.path) {
            try? fm.createDirectory(at: assets, withIntermediateDirectories: true)
        }
        return assets
    }

    func saveImage(from sourceURL: URL, preferredName: String, questionId: String) -> String? {
        ioQueue.sync {
            let baseName = URL(fileURLWithPath: preferredName).lastPathComponent
            let safeBase = baseName.isEmpty ? UUID().uuidString : baseName
            let fileName = "\(questionId)_\(safeBase)"
            let destURL = assetsDir.appendingPathComponent(fileName)

            do {
                let fm = FileManager.default
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                }
                try fm.copyItem(at: sourceURL, to: destURL)
                cache.removeObject(forKey: fileName as NSString)
                return fileName
            } catch {
                AppLogger.warning("QuestionAssetStore save failed (\(fileName)): \(error.localizedDescription)")
                return nil
            }
        }
    }

    func imageURL(for name: String) -> URL {
        if let bundled = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "ImportedAssets") {
            return bundled
        }
        return assetsDir.appendingPathComponent(name)
    }

    func loadImage(named name: String) -> PlatformImage? {
        if let cached = cache.object(forKey: name as NSString) {
            return cached
        }

        return ioQueue.sync {
            let url = imageURL(for: name)
#if canImport(UIKit)
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
#elseif canImport(AppKit)
            guard let image = NSImage(contentsOf: url) else { return nil }
#else
            return nil
#endif
            cache.setObject(image, forKey: name as NSString)
            return image
        }
    }

    func loadImageAsync(named name: String) async -> PlatformImage? {
        if let cached = cache.object(forKey: name as NSString) {
            return cached
        }
        return loadImage(named: name)
    }

    func clear() {
        ioQueue.sync {
            do {
                try FileManager.default.removeItem(at: assetsDir)
                cache.removeAllObjects()
            } catch {
                cache.removeAllObjects()
            }
        }
    }
}
