import Foundation

final class WeeklyGoalStore {
    static let shared = WeeklyGoalStore()

    private let key = "cfaquiz.weeklyGoal.v1"
    private let defaults = UserDefaults.standard

    private init() {}

    var weeklyQuestionGoal: Int {
        get {
            if defaults.object(forKey: key) == nil {
                return 50
            }
            return max(0, defaults.integer(forKey: key))
        }
        set {
            let clamped = max(0, newValue)
            defaults.set(clamped, forKey: key)
        }
    }
}
