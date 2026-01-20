import Foundation

final class QuestionDiskStore {
    static let shared = QuestionDiskStore()
    private init() {}

    enum StoreError: Error, LocalizedError {
        case readFailed(Error)
        case decodeFailed(Error)

        var errorDescription: String? {
            switch self {
            case .readFailed(let err):
                return "Lecture impossible: \(err.localizedDescription)"
            case .decodeFailed(let err):
                return "Decodage JSON impossible: \(err.localizedDescription)"
            }
        }
    }

    private var fileURL: URL {
        ImportPaths.ensureDirectories()
        return ImportPaths.questionsFile
    }

    func load() -> [CFAQuestion] {
        do {
            return try loadOrThrow()
        } catch {
            return []
        }
    }

    func loadOrThrow() throws -> [CFAQuestion] {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            do {
                return try JSONDecoder().decode([CFAQuestion].self, from: data)
            } catch {
                throw StoreError.decodeFailed(error)
            }
        } catch {
            throw StoreError.readFailed(error)
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
