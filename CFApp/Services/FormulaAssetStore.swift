import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class FormulaAssetStore {
    static let shared = FormulaAssetStore()
    private let cache = NSCache<NSString, PlatformImage>()
    private let ioQueue = DispatchQueue(label: "cfaquiz.formulaAssetStore", qos: .utility)

    private init() {}

    private var assetsDir: URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("CFAQuizApp", isDirectory: true)
        if !fm.fileExists(atPath: appDir.path) {
            try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        let assets = appDir.appendingPathComponent("ImportedFormulaAssets", isDirectory: true)
        if !fm.fileExists(atPath: assets.path) {
            try? fm.createDirectory(at: assets, withIntermediateDirectories: true)
        }
        return assets
    }

    func imageURL(for name: String) -> URL {
        if let bundled = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "ImportedFormulaAssets") {
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
        return await Task.detached(priority: .utility) { [weak self] in
            self?.loadImage(named: name)
        }.value
    }
}
