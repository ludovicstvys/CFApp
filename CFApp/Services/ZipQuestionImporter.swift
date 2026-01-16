import Foundation
import ZIPFoundation

/// Import de questions depuis un ZIP contenant un CSV + images.
struct ZipQuestionImporter {

    struct ImportResult {
        let questions: [CFAQuestion]
        let errors: [String]
        let warnings: [String]
    }

    enum ImportError: Error, LocalizedError {
        case missingCSV

        var errorDescription: String? {
            switch self {
            case .missingCSV: return "Aucun fichier CSV trouve dans le ZIP."
            }
        }
    }

    func importQuestions(from zipURL: URL) throws -> ImportResult {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("cfaquiz_import_\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        try fm.unzipItem(at: zipURL, to: tempDir)

        guard let csvURL = findFirstCSV(in: tempDir) else {
            throw ImportError.missingCSV
        }

        let data = try Data(contentsOf: csvURL)
        let csvResult = try CSVQuestionImporter().importQuestions(from: data)

        let imageIndex = buildImageIndex(in: tempDir)
        let assetStore = QuestionAssetStore.shared
        var warnings = csvResult.warnings

        let updated = csvResult.questions.map { q -> CFAQuestion in
            guard let raw = q.imageName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else {
                return q
            }

            guard let srcURL = resolveImageURL(named: raw, in: tempDir, index: imageIndex) else {
                warnings.append("Image introuvable pour question \(q.id): \(raw)")
                return q
            }

            guard let savedName = assetStore.saveImage(from: srcURL, preferredName: raw, questionId: q.id) else {
                warnings.append("Echec copie image pour question \(q.id): \(raw)")
                return q
            }

            return CFAQuestion(
                id: q.id,
                level: q.level,
                category: q.category,
                subcategory: q.subcategory,
                stem: q.stem,
                choices: q.choices,
                correctIndices: q.correctIndices,
                explanation: q.explanation,
                difficulty: q.difficulty,
                imageName: savedName,
                importedAt: q.importedAt
            )
        }

        return ImportResult(questions: updated, errors: csvResult.errors, warnings: warnings)
    }

    private func findFirstCSV(in dir: URL) -> URL? {
        let fm = FileManager.default
        let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey]) as? FileManager.DirectoryEnumerator
        for case let url as URL in enumerator ?? [] {
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                continue
            }
            if url.pathExtension.lowercased() == "csv" {
                return url
            }
        }
        return nil
    }

    private func buildImageIndex(in dir: URL) -> [String: URL] {
        let fm = FileManager.default
        let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey]) as? FileManager.DirectoryEnumerator
        var index: [String: URL] = [:]

        for case let url as URL in enumerator ?? [] {
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                continue
            }
            let ext = url.pathExtension.lowercased()
            if ["png", "jpg", "jpeg", "heic", "webp"].contains(ext) {
                let rel = url.path.replacingOccurrences(of: dir.path + "/", with: "")
                index[rel.lowercased()] = url
                index[url.lastPathComponent.lowercased()] = url
            }
        }
        return index
    }

    private func resolveImageURL(named raw: String, in dir: URL, index: [String: URL]) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        let direct = dir.appendingPathComponent(trimmed)
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }

        return index[trimmed.lowercased()]
    }
}
