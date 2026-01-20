import Foundation

final class CategoryGoalStore {
    static let shared = CategoryGoalStore()

    private let key = "cfaquiz.categoryGoals.v1"
    private let defaults = UserDefaults.standard

    private init() {}

    func loadGoals() -> [String: Int] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        do {
            return try JSONDecoder().decode([String: Int].self, from: data)
        } catch {
            return [:]
        }
    }

    func saveGoals(_ goals: [String: Int]) {
        do {
            let data = try JSONEncoder().encode(goals)
            defaults.set(data, forKey: key)
        } catch {
            // ignore
        }
    }
}
