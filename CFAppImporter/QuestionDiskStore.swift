import Foundation

final class QuestionDiskStore {
    static let shared = QuestionDiskStore()
    private init() {}

    private var fileURL: URL {
        ImportPaths.ensureDirectories()
        return ImportPaths.questionsFile
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
