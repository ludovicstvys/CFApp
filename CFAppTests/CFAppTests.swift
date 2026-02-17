import XCTest
@testable import CFApp

final class CFAppTests: XCTestCase {

    func testQuizEngineFiltersAndRandomMode() throws {
        let questions = [
            makeQuestion(id: "q1", level: .level1, category: CFACategory("Ethics"), stem: "Q1", choices: ["A", "B"], correct: [0]),
            makeQuestion(id: "q2", level: .level1, category: CFACategory("Quantitative Methods"), stem: "Q2", choices: ["A", "B"], correct: [1]),
            makeQuestion(id: "q3", level: .level2, category: CFACategory("Ethics"), stem: "Q3", choices: ["A", "B"], correct: [0])
        ]

        let engine = QuizEngine()
        var rng = SystemRandomNumberGenerator()

        let configFiltered = QuizConfig(
            level: .level1,
            mode: .revision,
            categories: [CFACategory("Ethics")],
            subcategories: [],
            numberOfQuestions: 10,
            shuffleAnswers: false,
            timeLimitSeconds: nil
        )
        let filtered = engine.prepare(questions: questions, config: configFiltered, rng: &rng)
        XCTAssertEqual(Set(filtered.map { $0.id }), Set(["q1"]))

        let configRandom = QuizConfig(
            level: .level1,
            mode: .random,
            categories: [CFACategory("Ethics")],
            subcategories: [],
            numberOfQuestions: 10,
            shuffleAnswers: false,
            timeLimitSeconds: nil
        )
        let random = engine.prepare(questions: questions, config: configRandom, rng: &rng)
        XCTAssertEqual(Set(random.map { $0.id }), Set(["q1", "q2"]))
    }

    func testQuizEngineRejectsInvalidQuestions() throws {
        let questions = [
            makeQuestion(id: "q1", level: .level1, category: CFACategory("Ethics"), stem: "Q1", choices: ["A"], correct: [0]),
            makeQuestion(id: "q2", level: .level1, category: CFACategory("Ethics"), stem: "Q2", choices: ["A", "B"], correct: [3]),
            makeQuestion(id: "q3", level: .level1, category: CFACategory("Ethics"), stem: "Q3", choices: ["A", "B"], correct: [0])
        ]

        let engine = QuizEngine()
        var rng = SystemRandomNumberGenerator()
        let config = QuizConfig(
            level: .level1,
            mode: .revision,
            categories: [CFACategory("Ethics")],
            subcategories: [],
            numberOfQuestions: 10,
            shuffleAnswers: false,
            timeLimitSeconds: nil
        )
        let prepared = engine.prepare(questions: questions, config: config, rng: &rng)
        XCTAssertEqual(prepared.count, 1)
        XCTAssertEqual(prepared.first?.id, "q3")
    }

    func testSpacedModePrioritizesOverdueQuestions() throws {
        let overdue = makeQuestion(id: "overdue", level: .level1, category: CFACategory("Ethics"), stem: "Overdue", choices: ["A", "B"], correct: [0])
        let fresh = makeQuestion(id: "fresh", level: .level1, category: CFACategory("Ethics"), stem: "Fresh", choices: ["A", "B"], correct: [0])

        var overdueHistory = QuestionHistory(id: overdue.id)
        overdueHistory.seenCount = 5
        overdueHistory.correctCount = 1
        overdueHistory.incorrectCount = 4
        overdueHistory.nextDueAt = Date().addingTimeInterval(-3 * 86_400)

        var freshHistory = QuestionHistory(id: fresh.id)
        freshHistory.seenCount = 5
        freshHistory.correctCount = 5
        freshHistory.incorrectCount = 0
        freshHistory.nextDueAt = Date().addingTimeInterval(5 * 86_400)

        let config = QuizConfig(
            level: .level1,
            mode: .spaced,
            categories: [CFACategory("Ethics")],
            subcategories: [],
            numberOfQuestions: 1,
            shuffleAnswers: false,
            timeLimitSeconds: nil
        )

        let engine = QuizEngine()
        var rng = SystemRandomNumberGenerator()
        let selected = engine.prepare(
            questions: [overdue, fresh],
            config: config,
            historyById: [overdue.id: overdueHistory, fresh.id: freshHistory],
            rng: &rng
        )

        XCTAssertEqual(selected.first?.id, overdue.id)
    }

    func testCSVImportWarningsAndParsing() throws {
        let csv = """
        id,level,category,subcategory,stem,choiceA,choiceB,choiceC,choiceD,answerIndex,explanation,difficulty
        q1,1,Ethics,,Question?,A,B,C,D,A,,x
        """
        let data = csv.data(using: .utf8) ?? Data()
        let importer = CSVQuestionImporter()
        let result = try importer.importQuestions(from: data)

        XCTAssertEqual(result.questions.count, 1)
        XCTAssertFalse(result.warnings.isEmpty)
    }

    func testStatsStoreSaveAndLoad() throws {
        let suiteName = "CFAppTests.StatsStore.SaveLoad.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let store = StatsStore(defaults: suite)
        store.clear()

        let attempt = QuizAttempt(
            level: .level1,
            mode: .revision,
            categories: [CFACategory("Ethics")],
            score: 1,
            total: 2,
            durationSeconds: 30,
            perCategory: [CFACategory("Ethics"): .init(correct: 1, total: 2)]
        )
        store.saveAttempt(attempt)
        let attempts = store.loadAttempts()
        XCTAssertEqual(attempts.first?.id, attempt.id)
    }

    func testStatsStoreMigratesLegacyPayload() throws {
        let suiteName = "CFAppTests.StatsStore.Migration.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let key = "cfaquiz.attempts.v1"
        let legacyAttempt = QuizAttempt(
            level: .level1,
            mode: .test,
            categories: [CFACategory("Ethics")],
            score: 5,
            total: 10,
            durationSeconds: 120,
            perCategory: [CFACategory("Ethics"): .init(correct: 5, total: 10)]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        suite.set(try encoder.encode([legacyAttempt]), forKey: key)

        let store = StatsStore(defaults: suite)
        let loaded = store.loadAttempts()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, legacyAttempt.id)
    }

    func testBackupRoundTrip() throws {
        let stats = InMemoryStatsStore()
        let history = InMemoryHistoryStore()
        let reports = InMemoryReportStore()
        let favorites = InMemoryFavoriteStore()
        let weekly = InMemoryWeeklyGoalStore()
        let categoryGoals = InMemoryCategoryGoalStore()
        let session = InMemorySessionStore()
        let disk = InMemoryQuestionDiskStore()
        let suiteName = "CFAppTests.Backup.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let attempt = QuizAttempt(
            level: .level1,
            mode: .mock,
            categories: [CFACategory("Ethics")],
            score: 8,
            total: 10,
            durationSeconds: 500,
            perCategory: [CFACategory("Ethics"): .init(correct: 8, total: 10)]
        )
        stats.saveAllAttempts([attempt])
        history.save(["q1": QuestionHistory(id: "q1")])
        let q = makeQuestion(id: "q1", level: .level1, category: CFACategory("Ethics"), stem: "S", choices: ["A", "B"], correct: [0])
        reports.saveReports([QuestionReport(question: q, issueType: .typo, note: "x")])
        favorites.save(["f1"])
        weekly.weeklyQuestionGoal = 77
        categoryGoals.saveGoals(["Ethics": 12])
        disk.save([q])
        defaults.set(2, forKey: "cfaquiz.themePreference")

        let service = AppBackupService(
            statsStore: stats,
            historyStore: history,
            reportStore: reports,
            favoriteStore: favorites,
            weeklyGoalStore: weekly,
            categoryGoalStore: categoryGoals,
            sessionStore: session,
            questionDiskStore: disk,
            defaults: defaults
        )

        let data = try service.exportBackupData()

        // Reset all to prove import restores them.
        stats.clear()
        history.clear()
        reports.clear()
        favorites.save([])
        weekly.weeklyQuestionGoal = 0
        categoryGoals.saveGoals([:])
        session.clear()
        disk.clear()
        defaults.set(0, forKey: "cfaquiz.themePreference")

        let summary = try service.importBackupData(data)
        XCTAssertEqual(summary.attempts, 1)
        XCTAssertEqual(summary.importedQuestions, 1)
        XCTAssertEqual(stats.loadAttempts().count, 1)
        XCTAssertEqual(disk.load().count, 1)
        XCTAssertEqual(weekly.weeklyQuestionGoal, 77)
        XCTAssertEqual(defaults.integer(forKey: "cfaquiz.themePreference"), 2)
    }

    // MARK: - Helpers

    private func makeQuestion(
        id: String,
        level: CFALevel,
        category: CFACategory,
        stem: String,
        choices: [String],
        correct: [Int]
    ) -> CFAQuestion {
        CFAQuestion(
            id: id,
            level: level,
            category: category,
            stem: stem,
            choices: choices,
            correctIndices: correct,
            explanation: "E"
        )
    }

}

private final class InMemoryStatsStore: StatsStoring {
    private var attempts: [QuizAttempt] = []
    func loadAttempts() -> [QuizAttempt] { attempts }
    func saveAttempt(_ attempt: QuizAttempt) { attempts.insert(attempt, at: 0) }
    func saveAllAttempts(_ attempts: [QuizAttempt]) { self.attempts = attempts }
    func clear() { attempts = [] }
}

private final class InMemoryHistoryStore: QuestionHistoryStoring {
    private var history: [String: QuestionHistory] = [:]
    func loadAll() -> [String: QuestionHistory] { history }
    func save(_ history: [String : QuestionHistory]) { self.history = history }
    func update(with results: [QuestionHistoryStore.QuestionResult], at date: Date) {}
    func clear() { history = [:] }
}

private final class InMemoryReportStore: QuestionReportStoring {
    private var reports: [QuestionReport] = []
    func loadReports() -> [QuestionReport] { reports }
    func saveReport(_ report: QuestionReport) { reports.insert(report, at: 0) }
    func saveReports(_ reports: [QuestionReport]) { self.reports = reports }
    func clear() { reports = [] }
}

private final class InMemoryFavoriteStore: FormulaFavoriteStoring {
    private var ids: Set<String> = []
    func load() -> Set<String> { ids }
    func save(_ ids: Set<String>) { self.ids = ids }
}

private final class InMemoryWeeklyGoalStore: WeeklyGoalStoring {
    var weeklyQuestionGoal: Int = 0
}

private final class InMemoryCategoryGoalStore: CategoryGoalStoring {
    private var goals: [String: Int] = [:]
    func loadGoals() -> [String : Int] { goals }
    func saveGoals(_ goals: [String : Int]) { self.goals = goals }
}

private final class InMemorySessionStore: QuizSessionStoring {
    private var session: QuizSession?
    func load() -> QuizSession? { session }
    func loadSummary() -> QuizSessionSummary? { nil }
    func save(_ session: QuizSession) { self.session = session }
    func clear() { session = nil }
}

private final class InMemoryQuestionDiskStore: QuestionDiskStoring {
    private var questions: [CFAQuestion] = []
    func load() -> [CFAQuestion] { questions }
    func save(_ questions: [CFAQuestion]) { self.questions = questions }
    func clear() { questions = [] }
}