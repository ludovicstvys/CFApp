import Foundation
import AppKit

final class FormulaAssetStore {
    static let shared = FormulaAssetStore()
    private init() {}

    private var assetsDir: URL {
        ImportPaths.ensureDirectories()
        return ImportPaths.formulaAssetsDir
    }

    func saveImage(from sourceURL: URL, preferredName: String, formulaId: String) -> String? {
        let baseName = URL(fileURLWithPath: preferredName).lastPathComponent
        let safeBase = baseName.isEmpty ? UUID().uuidString : baseName
        let fileName = "\(formulaId)_\(safeBase)"
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
