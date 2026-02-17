import Foundation

final class WeeklyGoalStore {
    static let shared = WeeklyGoalStore()

    private struct Envelope: Codable {
        let version: Int
        let weeklyQuestionGoal: Int
    }

    private let key = "cfaquiz.weeklyGoal.v1"
    private let currentVersion = 2
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "cfaquiz.weeklyGoalStore")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var weeklyQuestionGoal: Int {
        get {
            queue.sync {
                readGoal()
            }
        }
        set {
            queue.sync {
                writeGoal(max(0, newValue))
            }
        }
    }

    private func readGoal() -> Int {
        guard let data = defaults.data(forKey: key) else {
            if defaults.object(forKey: key) != nil {
                let legacyInt = max(0, defaults.integer(forKey: key))
                writeGoal(legacyInt)
                AppLogger.info("WeeklyGoalStore migrated legacy scalar payload to envelope v\(currentVersion).")
                return legacyInt
            }
            return 50
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data) {
            return max(0, envelope.weeklyQuestionGoal)
        }

        if let legacyInt = try? JSONDecoder().decode(Int.self, from: data) {
            let clamped = max(0, legacyInt)
            writeGoal(clamped)
            AppLogger.info("WeeklyGoalStore migrated legacy int payload to envelope v\(currentVersion).")
            return clamped
        }

        AppLogger.error("WeeklyGoalStore decode failed. Resetting to default.")
        return 50
    }

    private func writeGoal(_ goal: Int) {
        do {
            let data = try JSONEncoder().encode(Envelope(version: currentVersion, weeklyQuestionGoal: goal))
            defaults.set(data, forKey: key)
        } catch {
            AppLogger.error("WeeklyGoalStore persist failed: \(error.localizedDescription)")
        }
    }
}
