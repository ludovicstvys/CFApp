import Foundation
import Combine


@MainActor
final class HomeViewModel: ObservableObject {
    @Published var level: CFALevel = .level1
    @Published var mode: QuizMode = .revision
    @Published var selectedCategories: Set<CFACategory> = Set(CFACategory.allCases)

    /// Sous-catégories sélectionnées (si vide => pas de filtre)
    @Published var selectedSubcategories: Set<String> = []

    @Published var numberOfQuestions: Int = 15
    @Published var shuffleAnswers: Bool = false
    @Published var timeLimitMinutes: Int = 0 // 0 = pas de limite

    // Catalog (pour dériver les sous-catégories disponibles)
    @Published private(set) var availableSubcategories: [String] = []

    private let repo: QuestionRepository
    private var allQuestions: [CFAQuestion] = []

    init(repo: QuestionRepository = HybridQuestionRepository()) {
        self.repo = repo
        loadCatalog()
    }

    var config: QuizConfig {
        QuizConfig(
            level: level,
            mode: mode,
            categories: selectedCategories.isEmpty ? Set(CFACategory.allCases) : selectedCategories,
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
        selectedCategories = Set(CFACategory.allCases)
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

    // MARK: - Private

    private func loadCatalog() {
        do {
            allQuestions = try repo.loadAllQuestions()
        } catch {
            allQuestions = []
        }
        refreshAvailableSubcategories()
    }

    private func refreshAvailableSubcategories() {
        // Sous-catégories disponibles pour level + catégories sélectionnées
        let cats = selectedCategories.isEmpty ? Set(CFACategory.allCases) : selectedCategories

        let subs = allQuestions
            .filter { $0.level == level && cats.contains($0.category) }
            .compactMap { $0.subcategory?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let unique = Array(Set(subs)).sorted()
        availableSubcategories = unique

        // Si on filtre, supprimer les sous-catégories qui ne sont plus disponibles
        if !selectedSubcategories.isEmpty {
            selectedSubcategories = selectedSubcategories.intersection(Set(unique))
        }
    }
}
