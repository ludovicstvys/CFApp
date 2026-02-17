import Foundation

struct FormulaFilters: Codable {
    let selectedCategoryRawValue: String?
    let selectedTopic: String?
    let showFavoritesOnly: Bool
    let searchText: String

    static let `default` = FormulaFilters(
        selectedCategoryRawValue: nil,
        selectedTopic: nil,
        showFavoritesOnly: false,
        searchText: ""
    )
}

final class FormulaFilterStore {
    static let shared = FormulaFilterStore()

    private let key = "cfaquiz.formulas.filters.v1"
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "cfaquiz.formulaFilterStore")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> FormulaFilters {
        queue.sync {
            guard let data = defaults.data(forKey: key) else { return .default }
            guard let filters = try? JSONDecoder().decode(FormulaFilters.self, from: data) else {
                return .default
            }
            return filters
        }
    }

    func save(_ filters: FormulaFilters) {
        queue.sync {
            do {
                let data = try JSONEncoder().encode(filters)
                defaults.set(data, forKey: key)
            } catch {
                AppLogger.error("FormulaFilterStore persist failed: \(error.localizedDescription)")
            }
        }
    }
}
