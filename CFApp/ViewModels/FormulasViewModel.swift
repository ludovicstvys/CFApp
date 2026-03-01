import Foundation
import Combine

@MainActor
final class FormulasViewModel: ObservableObject {
    @Published private(set) var formulas: [CFAFormula] = []
    @Published private(set) var favoriteIds: Set<String>
    @Published var selectedCategory: CFACategory? {
        didSet {
            persistFilters()
            onCategoryChanged()
        }
    }
    @Published var selectedTopic: String? {
        didSet { persistFilters() }
    }
    @Published var showFavoritesOnly: Bool {
        didSet { persistFilters() }
    }
    @Published var searchText: String {
        didSet { persistFilters() }
    }

    private let questionRepo: QuestionRepository
    private let favoriteStore: FormulaFavoriteStoring
    private let filterStore: FormulaFilterStore
    private var questionsById: [String: CFAQuestion] = [:]

    init(
        repo: QuestionRepository = AppDependencies.shared.questionRepository,
        favoriteStore: FormulaFavoriteStoring = AppDependencies.shared.formulaFavoriteStore,
        filterStore: FormulaFilterStore = .shared
    ) {
        self.questionRepo = repo
        self.favoriteStore = favoriteStore
        self.filterStore = filterStore

        let filters = filterStore.load()
        self.favoriteIds = favoriteStore.load()
        self.selectedCategory = filters.selectedCategoryRawValue.map { CFACategory(rawValue: $0) }
        self.selectedTopic = filters.selectedTopic
        self.showFavoritesOnly = filters.showFavoritesOnly
        self.searchText = filters.searchText
        refresh()
    }

    func refresh() {
        do {
            formulas = try LocalFormulaStore().loadAllFormulas()
        } catch {
            formulas = []
            AppLogger.warning("FormulasViewModel failed to load formulas: \(error.localizedDescription)")
        }
        favoriteIds = favoriteStore.load()
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
            return matchesSearch(formula: formula)
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
            return matchesSearch(formula: formula)
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
        favoriteStore.save(updated)
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
        if let selectedTopic, !availableTopics.contains(selectedTopic) {
            self.selectedTopic = nil
        }
        persistFilters()
    }

    private func loadQuestions() {
        do {
            let questions = try questionRepo.loadAllQuestions()
            questionsById = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
        } catch {
            questionsById = [:]
            AppLogger.warning("FormulasViewModel failed to load linked questions: \(error.localizedDescription)")
        }
    }

    private func matchesSearch(formula: CFAFormula) -> Bool {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let normalizedNeedle = needle.folding(options: .diacriticInsensitive, locale: .current).lowercased()

        let haystack = [
            formula.title,
            formula.formula,
            formula.notes ?? "",
            formula.topic ?? "",
            formula.category.rawValue,
            formula.category.shortName
        ]
            .joined(separator: " ")
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()

        return haystack.contains(normalizedNeedle)
    }

    private func persistFilters() {
        let filters = FormulaFilters(
            selectedCategoryRawValue: selectedCategory?.rawValue,
            selectedTopic: selectedTopic,
            showFavoritesOnly: showFavoritesOnly,
            searchText: searchText
        )
        filterStore.save(filters)
    }
}
