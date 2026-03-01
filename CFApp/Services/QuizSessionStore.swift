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

    private struct SummaryPayload: Codable {
        let config: QuizConfig
        let currentIndex: Int
        let total: Int
    }

    private struct SummaryEnvelope: Codable {
        let version: Int
        let summary: SummaryPayload
    }

    private let key = "cfaquiz.session.v1"
    private let summaryKey = "cfaquiz.session.summary.v1"
    private let currentVersion = 2
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "cfaquiz.quizSessionStore")
    private var cachedSession: QuizSession?
    private var cachedSummary: QuizSessionSummary?
    private var didLoadSession = false
    private var pendingSession: QuizSession?
    private var pendingSummary: QuizSessionSummary?
    private var pendingPersistWorkItem: DispatchWorkItem?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> QuizSession? {
        queue.sync {
            if didLoadSession {
                return cachedSession
            }

            let decoded = decodeSession(from: defaults.data(forKey: key))
            cachedSession = decoded
            didLoadSession = true

            if let decoded {
                cachedSummary = summary(from: decoded)
            } else if let decodedSummary = decodeSummary(from: defaults.data(forKey: summaryKey)) {
                cachedSummary = decodedSummary
            }

            return decoded
        }
    }

    func loadSummary() -> QuizSessionSummary? {
        queue.sync {
            if let cachedSummary {
                return cachedSummary
            }

            if let decodedSummary = decodeSummary(from: defaults.data(forKey: summaryKey)) {
                cachedSummary = decodedSummary
                return decodedSummary
            }

            if !didLoadSession {
                cachedSession = decodeSession(from: defaults.data(forKey: key))
                didLoadSession = true
            }

            guard let cachedSession else { return nil }
            let summary = summary(from: cachedSession)
            cachedSummary = summary
            persistSummary(summary)
            return summary
        }
    }

    func save(_ session: QuizSession) {
        queue.sync {
            cachedSession = session
            didLoadSession = true

            let summary = summary(from: session)
            cachedSummary = summary

            pendingSession = session
            pendingSummary = summary
            schedulePersistLocked()
        }
    }

    func clear() {
        queue.sync {
            pendingPersistWorkItem?.cancel()
            pendingPersistWorkItem = nil
            pendingSession = nil
            pendingSummary = nil
            cachedSession = nil
            cachedSummary = nil
            didLoadSession = true
            defaults.removeObject(forKey: key)
            defaults.removeObject(forKey: summaryKey)
        }
    }

    private func schedulePersistLocked() {
        pendingPersistWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushPendingPersist()
        }
        pendingPersistWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func flushPendingPersist() {
        let session = pendingSession
        let summary = pendingSummary
        pendingSession = nil
        pendingSummary = nil
        pendingPersistWorkItem = nil

        if let session {
            persistSession(session)
        }
        if let summary {
            persistSummary(summary)
        }
    }

    private func summary(from session: QuizSession) -> QuizSessionSummary {
        QuizSessionSummary(
            config: session.config,
            currentIndex: session.currentIndex,
            total: session.questions.count
        )
    }

    private func persistSession(_ session: QuizSession) {
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

    private func persistSummary(_ summary: QuizSessionSummary) {
        do {
            let payload = SummaryPayload(
                config: summary.config,
                currentIndex: summary.currentIndex,
                total: summary.total
            )
            let envelope = SummaryEnvelope(version: currentVersion, summary: payload)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(envelope)
            defaults.set(data, forKey: summaryKey)
        } catch {
            AppLogger.error("QuizSessionStore summary persist failed: \(error.localizedDescription)")
        }
    }

    private func decodeSummary(from data: Data?) -> QuizSessionSummary? {
        guard let data else { return nil }

        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(SummaryEnvelope.self, from: data) {
            return QuizSessionSummary(
                config: envelope.summary.config,
                currentIndex: envelope.summary.currentIndex,
                total: envelope.summary.total
            )
        }

        if let payload = try? decoder.decode(SummaryPayload.self, from: data) {
            let summary = QuizSessionSummary(
                config: payload.config,
                currentIndex: payload.currentIndex,
                total: payload.total
            )
            persistSummary(summary)
            return summary
        }

        return nil
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
                persistSession(legacy)
                persistSummary(summary(from: legacy))
                AppLogger.info("QuizSessionStore migrated legacy payload to envelope v\(currentVersion).")
                return legacy
            } catch {
                AppLogger.error("QuizSessionStore decode failed: \(error.localizedDescription)")
                return nil
            }
        }
    }
}
