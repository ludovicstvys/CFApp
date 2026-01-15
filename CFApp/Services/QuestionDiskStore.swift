import Foundation

/// Stocke les questions importées sur disque (Application Support).
/// Elles seront fusionnées avec les questions du bundle (offline).
final class QuestionDiskStore {
    static let shared = QuestionDiskStore()
    private init() {}

    private var fileURL: URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("CFAQuizApp", isDirectory: true)
        if !fm.fileExists(atPath: appDir.path) {
            try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir.appendingPathComponent("ImportedQuestions.json")
    }

    func load() -> [CFAQuestion] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([CFAQuestion].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ questions: [CFAQuestion]) {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(questions)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // ignore
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
