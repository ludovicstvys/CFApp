import Foundation
#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

final class FormulaAssetStore {
    static let shared = FormulaAssetStore()
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
        let url = imageURL(for: name)
#if canImport(UIKit)
        return UIImage(contentsOfFile: url.path)
#elseif canImport(AppKit)
        return NSImage(contentsOf: url)
#else
        return nil
#endif
    }
}
