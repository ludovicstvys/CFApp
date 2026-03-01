import Foundation

/// Stocke localement les tentatives (offline) via UserDefaults.
/// Concu pour pouvoir ensuite synchroniser vers un backend.
final class StatsStore {
    static let shared = StatsStore()

    private struct Envelope: Codable {
        let version: Int
        let attempts: [QuizAttempt]
    }

    private let key = "cfaquiz.attempts.v1"
    private let currentVersion = 2
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "cfaquiz.statsStore")
    private var cachedAttempts: [QuizAttempt] = []
    private var didLoadAttempts = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAttempts() -> [QuizAttempt] {
        queue.sync {
            if didLoadAttempts {
                return cachedAttempts
            }
            let loaded = decodeAttempts(from: defaults.data(forKey: key)) ?? []
            cachedAttempts = loaded
            didLoadAttempts = true
            return loaded
        }
    }

    func saveAttempt(_ attempt: QuizAttempt) {
        queue.sync {
            var all: [QuizAttempt]
            if didLoadAttempts {
                all = cachedAttempts
            } else {
                all = decodeAttempts(from: defaults.data(forKey: key)) ?? []
            }
            all.insert(attempt, at: 0)
            cachedAttempts = all
            didLoadAttempts = true
            persist(all)
        }
    }

    func saveAllAttempts(_ attempts: [QuizAttempt]) {
        queue.sync {
            cachedAttempts = attempts
            didLoadAttempts = true
            persist(attempts)
        }
    }

    func clear() {
        queue.sync {
            cachedAttempts = []
            didLoadAttempts = true
            defaults.removeObject(forKey: key)
        }
    }

    private func decodeAttempts(from data: Data?) -> [QuizAttempt]? {
        guard let data else { return nil }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(Envelope.self, from: data)
            return envelope.attempts
        } catch {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let legacyAttempts = try decoder.decode([QuizAttempt].self, from: data)
                persist(legacyAttempts)
                AppLogger.info("StatsStore migrated legacy attempts payload to envelope v\(currentVersion).")
                return legacyAttempts
            } catch {
                AppLogger.error("StatsStore decode failed: \(error.localizedDescription)")
                return nil
            }
        }
    }

    private func persist(_ attempts: [QuizAttempt]) {
        do {
            let envelope = Envelope(version: currentVersion, attempts: attempts)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(envelope)
            defaults.set(data, forKey: key)
        } catch {
            AppLogger.error("StatsStore persist failed: \(error.localizedDescription)")
        }
    }
}
