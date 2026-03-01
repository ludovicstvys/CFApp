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
    var intervalDays: Double
    var easeFactor: Double
    var nextDueAt: Date?

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
        self.intervalDays = 0
        self.easeFactor = 2.5
        self.nextDueAt = nil
    }

    var accuracy: Double {
        guard seenCount > 0 else { return 0 }
        return Double(correctCount) / Double(seenCount)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case seenCount
        case correctCount
        case incorrectCount
        case correctStreak
        case incorrectStreak
        case lastAttemptAt
        case lastCorrectAt
        case lastIncorrectAt
        case intervalDays
        case easeFactor
        case nextDueAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        seenCount = try c.decodeIfPresent(Int.self, forKey: .seenCount) ?? 0
        correctCount = try c.decodeIfPresent(Int.self, forKey: .correctCount) ?? 0
        incorrectCount = try c.decodeIfPresent(Int.self, forKey: .incorrectCount) ?? 0
        correctStreak = try c.decodeIfPresent(Int.self, forKey: .correctStreak) ?? 0
        incorrectStreak = try c.decodeIfPresent(Int.self, forKey: .incorrectStreak) ?? 0
        lastAttemptAt = try c.decodeIfPresent(Date.self, forKey: .lastAttemptAt)
        lastCorrectAt = try c.decodeIfPresent(Date.self, forKey: .lastCorrectAt)
        lastIncorrectAt = try c.decodeIfPresent(Date.self, forKey: .lastIncorrectAt)
        intervalDays = try c.decodeIfPresent(Double.self, forKey: .intervalDays) ?? 0
        easeFactor = try c.decodeIfPresent(Double.self, forKey: .easeFactor) ?? 2.5
        nextDueAt = try c.decodeIfPresent(Date.self, forKey: .nextDueAt)
    }
}

final class QuestionHistoryStore {
    static let shared = QuestionHistoryStore()

    private struct Envelope: Codable {
        let version: Int
        let history: [String: QuestionHistory]
    }

    struct QuestionResult {
        let questionId: String
        let isCorrect: Bool
    }

    private let key = "cfaquiz.questionHistory.v1"
    private let currentVersion = 2
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "cfaquiz.questionHistoryStore")
    private var cachedHistory: [String: QuestionHistory] = [:]
    private var didLoadHistory = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAll() -> [String: QuestionHistory] {
        queue.sync {
            if didLoadHistory {
                return cachedHistory
            }
            let loaded = decodeHistory(from: defaults.data(forKey: key)) ?? [:]
            cachedHistory = loaded
            didLoadHistory = true
            return loaded
        }
    }

    func save(_ history: [String: QuestionHistory]) {
        queue.sync {
            cachedHistory = history
            didLoadHistory = true
            persist(history)
        }
    }

    func update(with results: [QuestionResult], at date: Date = Date()) {
        guard !results.isEmpty else { return }
        queue.sync {
            var all: [String: QuestionHistory]
            if didLoadHistory {
                all = cachedHistory
            } else {
                all = decodeHistory(from: defaults.data(forKey: key)) ?? [:]
            }
            for result in results {
                var entry = all[result.questionId] ?? QuestionHistory(id: result.questionId)
                updateEntry(&entry, isCorrect: result.isCorrect, at: date)
                all[result.questionId] = entry
            }
            cachedHistory = all
            didLoadHistory = true
            persist(all)
        }
    }

    func clear() {
        queue.sync {
            cachedHistory = [:]
            didLoadHistory = true
            defaults.removeObject(forKey: key)
        }
    }

    private func updateEntry(_ entry: inout QuestionHistory, isCorrect: Bool, at date: Date) {
        entry.seenCount += 1
        entry.lastAttemptAt = date

        if isCorrect {
            entry.correctCount += 1
            entry.correctStreak += 1
            entry.incorrectStreak = 0
            entry.lastCorrectAt = date

            let quality = 4.0
            let delta = 0.1 - (5.0 - quality) * (0.08 + (5.0 - quality) * 0.02)
            entry.easeFactor = max(1.3, min(2.8, entry.easeFactor + delta))

            switch entry.correctStreak {
            case 1:
                entry.intervalDays = 1
            case 2:
                entry.intervalDays = 3
            default:
                entry.intervalDays = max(1, entry.intervalDays * entry.easeFactor)
            }

            let nextInterval = max(1, Int(entry.intervalDays.rounded()))
            entry.nextDueAt = Calendar.current.date(byAdding: .day, value: nextInterval, to: date)
        } else {
            entry.incorrectCount += 1
            entry.incorrectStreak += 1
            entry.correctStreak = 0
            entry.lastIncorrectAt = date
            entry.easeFactor = max(1.3, entry.easeFactor - 0.2)
            entry.intervalDays = 1
            entry.nextDueAt = date
        }
    }

    private func decodeHistory(from data: Data?) -> [String: QuestionHistory]? {
        guard let data else { return nil }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(Envelope.self, from: data)
            return envelope.history
        } catch {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let legacy = try decoder.decode([String: QuestionHistory].self, from: data)
                persist(legacy)
                AppLogger.info("QuestionHistoryStore migrated legacy payload to envelope v\(currentVersion).")
                return legacy
            } catch {
                AppLogger.error("QuestionHistoryStore decode failed: \(error.localizedDescription)")
                return nil
            }
        }
    }

    private func persist(_ history: [String: QuestionHistory]) {
        do {
            let envelope = Envelope(version: currentVersion, history: history)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(envelope)
            defaults.set(data, forKey: key)
        } catch {
            AppLogger.error("QuestionHistoryStore persist failed: \(error.localizedDescription)")
        }
    }
}
