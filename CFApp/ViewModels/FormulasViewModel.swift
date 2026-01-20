import Foundation

@MainActor
final class FormulasViewModel: ObservableObject {
    @Published private(set) var formulas: [CFAFormula] = []
    @Published private(set) var favoriteIds: Set<String> = FormulaFavoriteStore.shared.load()
    @Published var selectedCategory: CFACategory? = nil
    @Published var selectedTopic: String? = nil
    @Published var showFavoritesOnly: Bool = false

    private let questionRepo: QuestionRepository
    private var questionsById: [String: CFAQuestion] = [:]

    init(repo: QuestionRepository = HybridQuestionRepository()) {
        self.questionRepo = repo
        refresh()
    }

    func refresh() {
        do {
            formulas = try LocalFormulaStore().loadAllFormulas()
        } catch {
            formulas = []
        }
        favoriteIds = FormulaFavoriteStore.shared.load()
        loadQuestions()
        normalizeFilters()
    }

    var availableCategories: [CFACategory] {
        let base = showFavoritesOnly ? formulas.filter { favoriteIds.contains($0.id) } : formulas
        return Array(Set(base.map { $0.category })).sorted { $0.rawValue < $1.rawValue }
    }

    var availableTopics: [String] {
        let filtered = formulas.filter { formula in
            if showFavoritesOnly, !favoriteIds.contains(formula.id) { return false }
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
            if showFavoritesOnly, !favoriteIds.contains(formula.id) { return false }
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

    func isFavorite(_ formula: CFAFormula) -> Bool {
        favoriteIds.contains(formula.id)
    }

    func toggleFavorite(_ formula: CFAFormula) {
        var updated = favoriteIds
        if updated.contains(formula.id) {
            updated.remove(formula.id)
        } else {
            updated.insert(formula.id)
        }
        favoriteIds = updated
        FormulaFavoriteStore.shared.save(updated)
    }

    func linkedQuestions(for formula: CFAFormula) -> [CFAQuestion] {
        let ids = (formula.questionIds ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let unique = Array(Set(ids)).filter { !$0.isEmpty }
        return unique.compactMap { questionsById[$0] }
            .sorted { $0.stem < $1.stem }
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

    private func loadQuestions() {
        do {
            let questions = try questionRepo.loadAllQuestions()
            questionsById = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
        } catch {
            questionsById = [:]
        }
    }
}
