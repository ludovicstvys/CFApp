import Foundation

/// Stocke les questions importees sur disque (Application Support).
/// Elles seront fusionnees avec les questions du bundle (offline).
final class QuestionDiskStore {
    static let shared = QuestionDiskStore()

    private struct Envelope: Codable {
        let version: Int
        let questions: [CFAQuestion]
    }

    private let currentVersion = 2
    private let queue = DispatchQueue(label: "cfaquiz.questionDiskStore")

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
        queue.sync {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                if let envelope = try? decoder.decode(Envelope.self, from: data) {
                    return envelope.questions
                }
                let legacy = try decoder.decode([CFAQuestion].self, from: data)
                persist(legacy)
                AppLogger.info("QuestionDiskStore migrated legacy file payload to envelope v\(currentVersion).")
                return legacy
            } catch {
                return []
            }
        }
    }

    func save(_ questions: [CFAQuestion]) {
        queue.sync {
            persist(questions)
        }
    }

    func clear() {
        queue.sync {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                // no-op when file does not exist
            }
        }
    }

    private func persist(_ questions: [CFAQuestion]) {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(Envelope(version: currentVersion, questions: questions))
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            AppLogger.error("QuestionDiskStore persist failed: \(error.localizedDescription)")
        }
    }
}
