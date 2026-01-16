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

    private let key = "cfaquiz.session.v1"
    private let defaults = UserDefaults.standard

    private init() {}

    func load() -> QuizSession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(QuizSession.self, from: data)
        } catch {
            return nil
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
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(session)
            defaults.set(data, forKey: key)
        } catch {
            // ignore
        }
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
