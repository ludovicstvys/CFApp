import Foundation

struct QuestionHistory: Codable {
    let id: String
    var seenCount: Int
    var correctCount: Int
    var incorrectCount: Int
    var correctStreak: Int
    var incorrectStreak: Int
    var lastAttemptAt: Date?
    var lastCorrectAt: Date?
    var lastIncorrectAt: Date?

    init(id: String) {
        self.id = id
        self.seenCount = 0
        self.correctCount = 0
        self.incorrectCount = 0
        self.correctStreak = 0
        self.incorrectStreak = 0
        self.lastAttemptAt = nil
        self.lastCorrectAt = nil
        self.lastIncorrectAt = nil
    }

    var accuracy: Double {
        guard seenCount > 0 else { return 0 }
        return Double(correctCount) / Double(seenCount)
    }
}

final class QuestionHistoryStore {
    static let shared = QuestionHistoryStore()

    private let key = "cfaquiz.questionHistory.v1"
    private let defaults = UserDefaults.standard

    private init() {}

    struct QuestionResult {
        let questionId: String
        let isCorrect: Bool
    }

    func loadAll() -> [String: QuestionHistory] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([String: QuestionHistory].self, from: data)
        } catch {
            return [:]
        }
    }

    func save(_ history: [String: QuestionHistory]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(history)
            defaults.set(data, forKey: key)
        } catch {
            // ignore
        }
    }

    func update(with results: [QuestionResult], at date: Date = Date()) {
        guard !results.isEmpty else { return }
        var all = loadAll()
        for result in results {
            var entry = all[result.questionId] ?? QuestionHistory(id: result.questionId)
            entry.seenCount += 1
            entry.lastAttemptAt = date

            if result.isCorrect {
                entry.correctCount += 1
                entry.correctStreak += 1
                entry.incorrectStreak = 0
                entry.lastCorrectAt = date
            } else {
                entry.incorrectCount += 1
                entry.incorrectStreak += 1
                entry.correctStreak = 0
                entry.lastIncorrectAt = date
            }

            all[result.questionId] = entry
        }
        save(all)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
