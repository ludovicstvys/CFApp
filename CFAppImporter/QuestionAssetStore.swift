import Foundation
import AppKit

final class QuestionAssetStore {
    static let shared = QuestionAssetStore()
    private init() {}

    private var assetsDir: URL {
        ImportPaths.ensureDirectories()
        return ImportPaths.assetsDir
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
