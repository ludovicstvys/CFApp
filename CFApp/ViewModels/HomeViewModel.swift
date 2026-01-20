import Foundation
import Combine


@MainActor
final class HomeViewModel: ObservableObject {
    @Published var level: CFALevel = .level1
    @Published var mode: QuizMode = .revision {
        didSet {
            refreshFiltersForMode()
        }
    }
    @Published var selectedCategories: Set<CFACategory> = []

    /// Sous-catégories sélectionnées (si vide => pas de filtre)
    @Published var selectedSubcategories: Set<String> = []

    @Published var numberOfQuestions: Int = 15
    @Published var shuffleAnswers: Bool = false
    @Published var timeLimitMinutes: Int = 0 // 0 = pas de limite

    // Catalog (pour dériver les sous-catégories disponibles)
    @Published private(set) var availableCategories: [CFACategory] = []
    @Published private(set) var availableSubcategories: [String] = []
    @Published private(set) var savedSessionSummary: QuizSessionSummary? = nil

    private let repo: QuestionRepository
    private var allQuestions: [CFAQuestion] = []
    private var allFormulas: [CFAFormula] = []
    private var questionCategories: [CFACategory] = []
    private var formulaCategories: [CFACategory] = []

    init(repo: QuestionRepository = HybridQuestionRepository()) {
        self.repo = repo
        loadCatalog()
        refreshSavedSession()
    }

    var config: QuizConfig {
        QuizConfig(
            level: level,
            mode: mode,
            categories: selectedCategories.isEmpty ? Set(availableCategories) : selectedCategories,
            subcategories: selectedSubcategories,
            numberOfQuestions: max(1, numberOfQuestions),
            shuffleAnswers: shuffleAnswers,
            timeLimitSeconds: timeLimitMinutes > 0 ? timeLimitMinutes * 60 : nil
        )
    }

    func toggleCategory(_ cat: CFACategory) {
        if selectedCategories.contains(cat) {
            selectedCategories.remove(cat)
        } else {
            selectedCategories.insert(cat)
        }
        refreshAvailableSubcategories()
    }

    func selectAllCategories() {
        selectedCategories = Set(availableCategories)
        refreshAvailableSubcategories()
    }

    func clearCategories() {
        selectedCategories.removeAll()
        refreshAvailableSubcategories()
    }

    func toggleSubcategory(_ sub: String) {
        if selectedSubcategories.contains(sub) {
            selectedSubcategories.remove(sub)
        } else {
            selectedSubcategories.insert(sub)
        }
    }

    func clearSubcategories() {
        selectedSubcategories.removeAll()
    }

    func selectAllSubcategories() {
        selectedSubcategories = Set(availableSubcategories)
    }

    func onLevelChanged() {
        refreshAvailableSubcategories()
    }

    func refreshSavedSession() {
        savedSessionSummary = QuizSessionStore.shared.loadSummary()
    }

    func clearSavedSession() {
        QuizSessionStore.shared.clear()
        refreshSavedSession()
    }

    // MARK: - Private

    private func loadCatalog() {
        do {
            allQuestions = try repo.loadAllQuestions()
        } catch {
            allQuestions = []
        }
        questionCategories = Array(Set(allQuestions.map { $0.category }))
            .sorted { $0.rawValue < $1.rawValue }

        do {
            allFormulas = try LocalFormulaStore().loadAllFormulas()
        } catch {
            allFormulas = []
        }
        formulaCategories = Array(Set(allFormulas.map { $0.category }))
            .sorted { $0.rawValue < $1.rawValue }

        refreshFiltersForMode()
    }

    private func refreshAvailableSubcategories() {
        let cats = selectedCategories.isEmpty ? Set(availableCategories) : selectedCategories

        if mode == .formulas {
            let topics = allFormulas
                .filter { cats.contains($0.category) }
                .compactMap { $0.topic?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            availableSubcategories = Array(Set(topics)).sorted()
        } else {
            let subs = allQuestions
                .filter { $0.level == level && cats.contains($0.category) }
                .compactMap { $0.subcategory?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            availableSubcategories = Array(Set(subs)).sorted()
        }

        // Si on filtre, supprimer les sous-catégories qui ne sont plus disponibles
        if !selectedSubcategories.isEmpty {
            selectedSubcategories = selectedSubcategories.intersection(Set(availableSubcategories))
        }
    }

    private func refreshFiltersForMode() {
        if mode == .formulas {
            availableCategories = formulaCategories
        } else {
            availableCategories = questionCategories
        }

        if selectedCategories.isEmpty {
            selectedCategories = Set(availableCategories)
        } else {
            selectedCategories = selectedCategories.intersection(Set(availableCategories))
        }

        refreshAvailableSubcategories()
    }
}
