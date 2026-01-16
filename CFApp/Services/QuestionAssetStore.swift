import Foundation
import UIKit

/// Stocke les images importees sur disque (Application Support).
final class QuestionAssetStore {
    static let shared = QuestionAssetStore()
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
            return fileName
        } catch {
            return nil
        }
    }

    func imageURL(for name: String) -> URL {
        assetsDir.appendingPathComponent(name)
    }

    func loadImage(named name: String) -> UIImage? {
        let url = imageURL(for: name)
        return UIImage(contentsOfFile: url.path)
    }

    func clear() {
        try? FileManager.default.removeItem(at: assetsDir)
    }
}
