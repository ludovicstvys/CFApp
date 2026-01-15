import Foundation

/// Stocke localement les tentatives (offline) via UserDefaults.
/// Conçu pour pouvoir ensuite synchroniser vers un backend.
final class StatsStore {
    static let shared = StatsStore()

    private let key = "cfaquiz.attempts.v1"
    private let defaults = UserDefaults.standard

    private init() {}

    func loadAttempts() -> [QuizAttempt] {
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([QuizAttempt].self, from: data)
        } catch {
            // Si corruption: on ne crash pas
            return []
        }
    }

    func saveAttempt(_ attempt: QuizAttempt) {
        var all = loadAttempts()
        all.insert(attempt, at: 0) // plus récent en premier

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(all)
            defaults.set(data, forKey: key)
        } catch {
            // Ignore : on pourrait loguer dans un fichier local si besoin
        }
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
