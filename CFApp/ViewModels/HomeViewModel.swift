import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    private struct LaunchPreset: Codable {
        let version: Int
        let modeRawValue: String
        let levelRawValue: Int
        let categories: [String]
        let subcategories: [String]
        let numberOfQuestions: Int
        let shuffleAnswers: Bool
        let timeLimitMinutes: Int
        let mockExamMinutes: Int
    }

    @Published var level: CFALevel = .level1
    @Published var mode: QuizMode = .revision {
        didSet { refreshFiltersForMode() }
    }
    @Published var selectedCategories: Set<CFACategory> = []
    /// Selected subcategories/topics (if empty => no sub-filter).
    @Published var selectedSubcategories: Set<String> = []

    @Published var numberOfQuestions: Int = 15
    @Published var shuffleAnswers: Bool = false
    @Published var timeLimitMinutes: Int = 0
    @Published var mockExamMinutes: Int = 180

    @Published private(set) var availableCategories: [CFACategory] = []
    @Published private(set) var availableSubcategories: [String] = []
    @Published private(set) var savedSessionSummary: QuizSessionSummary? = nil
    @Published private(set) var didRestoreLastPreset: Bool = false

    private let repo: QuestionRepository
    private let sessionStore: QuizSessionStoring
    private let defaults: UserDefaults
    private let loadQueue = DispatchQueue(label: "cfaquiz.homeViewModel.load", qos: .userInitiated)
    private let lastPresetKey = "cfaquiz.home.lastPreset.v1"
    private let lastPresetVersion = 1
    private var allQuestions: [CFAQuestion] = []
    private var allFormulas: [CFAFormula] = []
    private var questionCategories: [CFACategory] = []
    private var formulaCategories: [CFACategory] = []
    private var loadGeneration = 0
    private var didApplyPersistedPreset = false

    init(
        repo: QuestionRepository = AppDependencies.shared.questionRepository,
        sessionStore: QuizSessionStoring = AppDependencies.shared.sessionStore,
        defaults: UserDefaults = .standard
    ) {
        self.repo = repo
        self.sessionStore = sessionStore
        self.defaults = defaults
        loadCatalog()
        refreshSavedSession()
    }

    var config: QuizConfig {
        let effectiveTimeLimit: Int?
        switch mode {
        case .test:
            effectiveTimeLimit = timeLimitMinutes > 0 ? timeLimitMinutes * 60 : nil
        case .mock:
            effectiveTimeLimit = max(30, mockExamMinutes) * 60
        default:
            effectiveTimeLimit = nil
        }

        return QuizConfig(
            level: level,
            mode: mode,
            categories: selectedCategories.isEmpty ? Set(availableCategories) : selectedCategories,
            subcategories: selectedSubcategories,
            numberOfQuestions: max(1, numberOfQuestions),
            shuffleAnswers: shuffleAnswers,
            timeLimitSeconds: effectiveTimeLimit
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
        savedSessionSummary = sessionStore.loadSummary()
    }

    func clearSavedSession() {
        sessionStore.clear()
        refreshSavedSession()
    }

    func markCurrentConfigAsLastUsed() {
        persistCurrentPreset()
    }

    func applyTargetedQuiz(
        categories: [CFACategory],
        level: CFALevel,
        questionCount: Int
    ) {
        self.mode = .revision
        self.level = level
        self.numberOfQuestions = max(5, min(120, questionCount))
        self.timeLimitMinutes = 0

        refreshFiltersForMode()

        let allowed = Set(availableCategories)
        let filtered = Set(categories).intersection(allowed)
        selectedCategories = filtered.isEmpty ? allowed : filtered
        selectedSubcategories.removeAll()
        refreshAvailableSubcategories()

        persistCurrentPreset()
    }

    // MARK: - Private

    private func loadCatalog() {
        loadGeneration += 1
        let generation = loadGeneration
        let repo = self.repo

        loadQueue.async {
            let loadedQuestions: [CFAQuestion]
            do {
                loadedQuestions = try repo.loadAllQuestions()
            } catch {
                AppLogger.warning("HomeViewModel failed to load questions: \(error.localizedDescription)")
                loadedQuestions = []
            }
            let questionCategories = Array(Set(loadedQuestions.map { $0.category }))
                .sorted { $0.rawValue < $1.rawValue }

            let loadedFormulas: [CFAFormula]
            do {
                loadedFormulas = try LocalFormulaStore().loadAllFormulas()
            } catch {
                AppLogger.warning("HomeViewModel failed to load formulas: \(error.localizedDescription)")
                loadedFormulas = []
            }
            let formulaCategories = Array(Set(loadedFormulas.map { $0.category }))
                .sorted { $0.rawValue < $1.rawValue }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.loadGeneration == generation else { return }
                self.allQuestions = loadedQuestions
                self.questionCategories = questionCategories
                self.allFormulas = loadedFormulas
                self.formulaCategories = formulaCategories

                if !self.applyPersistedPresetIfNeeded() {
                    self.refreshFiltersForMode()
                }
            }
        }
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

    @discardableResult
    private func applyPersistedPresetIfNeeded() -> Bool {
        guard !didApplyPersistedPreset else { return false }
        didApplyPersistedPreset = true

        guard let data = defaults.data(forKey: lastPresetKey) else { return false }
        guard let preset = try? JSONDecoder().decode(LaunchPreset.self, from: data) else { return false }
        guard preset.version == lastPresetVersion else { return false }

        if let restoredMode = QuizMode(rawValue: preset.modeRawValue) {
            mode = restoredMode
        }
        if let restoredLevel = CFALevel(rawValue: preset.levelRawValue) {
            level = restoredLevel
        }

        numberOfQuestions = max(5, min(120, preset.numberOfQuestions))
        shuffleAnswers = preset.shuffleAnswers
        timeLimitMinutes = max(0, min(180, preset.timeLimitMinutes))
        mockExamMinutes = max(30, min(360, preset.mockExamMinutes))

        selectedCategories = Set(preset.categories.map { CFACategory($0) })
        selectedSubcategories = Set(
            preset.subcategories
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        refreshFiltersForMode()
        didRestoreLastPreset = true
        return true
    }

    private func persistCurrentPreset() {
        let payload = LaunchPreset(
            version: lastPresetVersion,
            modeRawValue: mode.rawValue,
            levelRawValue: level.rawValue,
            categories: selectedCategories.map(\.rawValue).sorted(),
            subcategories: selectedSubcategories.sorted(),
            numberOfQuestions: max(5, min(120, numberOfQuestions)),
            shuffleAnswers: shuffleAnswers,
            timeLimitMinutes: max(0, min(180, timeLimitMinutes)),
            mockExamMinutes: max(30, min(360, mockExamMinutes))
        )

        do {
            let data = try JSONEncoder().encode(payload)
            defaults.set(data, forKey: lastPresetKey)
        } catch {
            AppLogger.warning("HomeViewModel failed to persist launch preset: \(error.localizedDescription)")
        }
    }
}
