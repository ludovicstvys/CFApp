import Foundation

final class CategoryGoalStore {
    static let shared = CategoryGoalStore()

    private struct Envelope: Codable {
        let version: Int
        let goals: [String: Int]
    }

    private let key = "cfaquiz.categoryGoals.v1"
    private let currentVersion = 2
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "cfaquiz.categoryGoalStore")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadGoals() -> [String: Int] {
        queue.sync {
            decodeGoals(from: defaults.data(forKey: key)) ?? [:]
        }
    }

    func saveGoals(_ goals: [String: Int]) {
        queue.sync {
            do {
                let envelope = Envelope(version: currentVersion, goals: goals)
                let data = try JSONEncoder().encode(envelope)
                defaults.set(data, forKey: key)
            } catch {
                AppLogger.error("CategoryGoalStore persist failed: \(error.localizedDescription)")
            }
        }
    }

    private func decodeGoals(from data: Data?) -> [String: Int]? {
        guard let data else { return nil }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data) {
            return envelope.goals
        }

        if let legacy = try? JSONDecoder().decode([String: Int].self, from: data) {
            saveGoals(legacy)
            AppLogger.info("CategoryGoalStore migrated legacy payload to envelope v\(currentVersion).")
            return legacy
        }

        AppLogger.error("CategoryGoalStore decode failed.")
        return nil
    }
}
