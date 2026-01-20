import Foundation

@MainActor
final class FormulasViewModel: ObservableObject {
    @Published private(set) var formulas: [CFAFormula] = []
    @Published var selectedCategory: CFACategory? = nil
    @Published var selectedTopic: String? = nil

    init() {
        refresh()
    }

    func refresh() {
        do {
            formulas = try LocalFormulaStore().loadAllFormulas()
        } catch {
            formulas = []
        }
        normalizeFilters()
    }

    var availableCategories: [CFACategory] {
        Array(Set(formulas.map { $0.category })).sorted { $0.rawValue < $1.rawValue }
    }

    var availableTopics: [String] {
        let filtered = formulas.filter { formula in
            if let selectedCategory, formula.category != selectedCategory { return false }
            return true
        }
        let topics = filtered.compactMap { formula in
            formula.topic?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return Array(Set(topics)).filter { !$0.isEmpty }.sorted()
    }

    var filteredFormulas: [CFAFormula] {
        formulas.filter { formula in
            if let selectedCategory, formula.category != selectedCategory { return false }
            if let selectedTopic {
                let topic = (formula.topic ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if topic != selectedTopic { return false }
            }
            return true
        }
        .sorted { lhs, rhs in
            if lhs.category.rawValue != rhs.category.rawValue {
                return lhs.category.rawValue < rhs.category.rawValue
            }
            let leftTopic = lhs.topic ?? ""
            let rightTopic = rhs.topic ?? ""
            if leftTopic != rightTopic {
                return leftTopic < rightTopic
            }
            return lhs.title < rhs.title
        }
    }

    func onCategoryChanged() {
        if let selectedTopic, !availableTopics.contains(selectedTopic) {
            self.selectedTopic = nil
        }
    }

    private func normalizeFilters() {
        if let selectedCategory, !availableCategories.contains(selectedCategory) {
            self.selectedCategory = nil
        }
        onCategoryChanged()
    }
}
