import Foundation

@MainActor
final class FormulaQuizViewModel: ObservableObject {
    struct FormulaAnswerRecord: Identifiable, Hashable {
        let id: String
        let formulaId: String
        let isCorrect: Bool
        let category: CFACategory
        let topic: String?
        let title: String
    }

    enum State: Equatable {
        case idle
        case loading
        case running
        case finished
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var config: QuizConfig = .default()
    @Published private(set) var formulas: [CFAFormula] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var revealed: Bool = false
    @Published private(set) var records: [FormulaAnswerRecord] = []

    private var rng = SystemRandomNumberGenerator()

    var current: CFAFormula? {
        guard currentIndex >= 0 && currentIndex < formulas.count else { return nil }
        return formulas[currentIndex]
    }

    var score: Int {
        records.filter { $0.isCorrect }.count
    }

    var total: Int { formulas.count }

    func start(config: QuizConfig) {
        self.config = config
        state = .loading
        currentIndex = 0
        revealed = false
        records = []

        do {
            let all = try LocalFormulaStore().loadAllFormulas()
            let filtered = filterFormulas(all, config: config)
            let n = min(config.numberOfQuestions, filtered.count)
            let pool = filtered.shuffled(using: &rng)
            formulas = Array(pool.prefix(n))
            state = formulas.isEmpty ? .failed("Aucune formule disponible pour ces filtres.") : .running
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func reveal() {
        revealed = true
    }

    func markKnown() {
        recordCurrent(isCorrect: true)
        goNext()
    }

    func markUnknown() {
        recordCurrent(isCorrect: false)
        if let current {
            var favorites = FormulaFavoriteStore.shared.load()
            favorites.insert(current.id)
            FormulaFavoriteStore.shared.save(favorites)
        }
        goNext()
    }

    func skip() {
        recordCurrent(isCorrect: false)
        goNext()
    }

    func restart() {
        start(config: config)
    }

    private func filterFormulas(_ formulas: [CFAFormula], config: QuizConfig) -> [CFAFormula] {
        let allowAllCategories = config.categories.isEmpty
        let allowedTopics = config.subcategories

        return formulas.filter { formula in
            if !allowAllCategories, !config.categories.contains(formula.category) { return false }
            if !allowedTopics.isEmpty {
                let topic = (formula.topic ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return allowedTopics.contains(topic)
            }
            return true
        }
    }

    private func goNext() {
        revealed = false
        if currentIndex + 1 < formulas.count {
            currentIndex += 1
        } else {
            state = .finished
        }
    }

    private func recordCurrent(isCorrect: Bool) {
        guard let formula = current else { return }
        let record = FormulaAnswerRecord(
            id: UUID().uuidString,
            formulaId: formula.id,
            isCorrect: isCorrect,
            category: formula.category,
            topic: formula.topic,
            title: formula.title
        )
        records.append(record)
    }
}
