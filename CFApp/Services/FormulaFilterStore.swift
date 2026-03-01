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
    private var cachedFilters: FormulaFilters = .default
    private var didLoadFilters = false
    private var pendingPersistWorkItem: DispatchWorkItem?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> FormulaFilters {
        queue.sync {
            if didLoadFilters {
                return cachedFilters
            }
            guard let data = defaults.data(forKey: key) else {
                cachedFilters = .default
                didLoadFilters = true
                return .default
            }
            guard let filters = try? JSONDecoder().decode(FormulaFilters.self, from: data) else {
                cachedFilters = .default
                didLoadFilters = true
                return .default
            }
            cachedFilters = filters
            didLoadFilters = true
            return filters
        }
    }

    func save(_ filters: FormulaFilters) {
        queue.sync {
            cachedFilters = filters
            didLoadFilters = true
            schedulePersistLocked()
        }
    }

    private func schedulePersistLocked() {
        pendingPersistWorkItem?.cancel()
        let snapshot = cachedFilters
        let workItem = DispatchWorkItem { [weak self] in
            self?.persist(snapshot)
        }
        pendingPersistWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private func persist(_ filters: FormulaFilters) {
        do {
            let data = try JSONEncoder().encode(filters)
            defaults.set(data, forKey: key)
        } catch {
            AppLogger.error("FormulaFilterStore persist failed: \(error.localizedDescription)")
        }
    }
}
