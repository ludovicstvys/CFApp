import Foundation

final class FormulaFavoriteStore {
    static let shared = FormulaFavoriteStore()

    private let key = "cfaquiz.formulaFavorites.v1"
    private let defaults = UserDefaults.standard

    private init() {}

    func load() -> Set<String> {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(decoded)
    }

    func save(_ ids: Set<String>) {
        do {
            let data = try JSONEncoder().encode(Array(ids))
            defaults.set(data, forKey: key)
        } catch {
            // ignore
        }
    }
}
