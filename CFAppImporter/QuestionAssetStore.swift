import Foundation
import AppKit

final class QuestionAssetStore {
    static let shared = QuestionAssetStore()
    private init() {}

    private var assetsDir: URL {
        let fm = FileManager.default
        let root = repoRootURL() ?? URL(fileURLWithPath: fm.currentDirectoryPath)
        let appDir = root.appendingPathComponent("CFApp", isDirectory: true)
        if !fm.fileExists(atPath: appDir.path) {
            try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        let assets = appDir.appendingPathComponent("ImportedAssets", isDirectory: true)
        if !fm.fileExists(atPath: assets.path) {
            try? fm.createDirectory(at: assets, withIntermediateDirectories: true)
        }
        return assets
    }

    private func repoRootURL() -> URL? {
        let env = ProcessInfo.processInfo.environment["CFAPP_REPO_ROOT"]
        if let env, !env.isEmpty {
            return URL(fileURLWithPath: env)
        }

        let fm = FileManager.default
        var current = URL(fileURLWithPath: fm.currentDirectoryPath)
        while current.path != "/" {
            let marker = current.appendingPathComponent("CFApp.xcodeproj").path
            if fm.fileExists(atPath: marker) {
                return current
            }
            current.deleteLastPathComponent()
        }
        return nil
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

    func clear() {
        try? FileManager.default.removeItem(at: assetsDir)
    }
}
