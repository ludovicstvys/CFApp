import Foundation

struct QuizSession: Codable {
    struct StoredPreparedQuestion: Codable, Hashable {
        let id: String
        let original: CFAQuestion
        let stem: String
        let choices: [String]
        let correctIndices: [Int]
    }

    struct StoredAnswerRecord: Codable, Hashable {
        let id: String
        let questionId: String
        let selectedIndices: [Int]
        let correctIndices: [Int]
        let category: CFACategory
        let subcategory: String?
        let stem: String
        let choices: [String]
        let explanation: String
    }

    let config: QuizConfig
    let questions: [StoredPreparedQuestion]
    let currentIndex: Int
    let selectedSet: [Int]
    let isSubmitted: Bool
    let records: [StoredAnswerRecord]
    let remainingSeconds: Int?
    let startedAt: Date?
}

struct QuizSessionSummary {
    let config: QuizConfig
    let currentIndex: Int
    let total: Int
}

final class QuizSessionStore {
    static let shared = QuizSessionStore()

    private struct Envelope: Codable {
        let version: Int
        let session: QuizSession
    }

    private let key = "cfaquiz.session.v1"
    private let currentVersion = 2
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "cfaquiz.quizSessionStore")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> QuizSession? {
        queue.sync {
            decodeSession(from: defaults.data(forKey: key))
        }
    }

    func loadSummary() -> QuizSessionSummary? {
        guard let session = load() else { return nil }
        return QuizSessionSummary(
            config: session.config,
            currentIndex: session.currentIndex,
            total: session.questions.count
        )
    }

    func save(_ session: QuizSession) {
        queue.sync {
            do {
                let envelope = Envelope(version: currentVersion, session: session)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(envelope)
                defaults.set(data, forKey: key)
            } catch {
                AppLogger.error("QuizSessionStore persist failed: \(error.localizedDescription)")
            }
        }
    }

    func clear() {
        queue.sync {
            defaults.removeObject(forKey: key)
        }
    }

    private func decodeSession(from data: Data?) -> QuizSession? {
        guard let data else { return nil }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(Envelope.self, from: data)
            return envelope.session
        } catch {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let legacy = try decoder.decode(QuizSession.self, from: data)
                save(legacy)
                AppLogger.info("QuizSessionStore migrated legacy payload to envelope v\(currentVersion).")
                return legacy
            } catch {
                AppLogger.error("QuizSessionStore decode failed: \(error.localizedDescription)")
                return nil
            }
        }
    }
}
