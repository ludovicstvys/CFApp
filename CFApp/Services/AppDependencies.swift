import Foundation

protocol StatsStoring {
    func loadAttempts() -> [QuizAttempt]
    func saveAttempt(_ attempt: QuizAttempt)
    func saveAllAttempts(_ attempts: [QuizAttempt])
    func clear()
}

protocol QuestionHistoryStoring {
    func loadAll() -> [String: QuestionHistory]
    func save(_ history: [String: QuestionHistory])
    func update(with results: [QuestionHistoryStore.QuestionResult], at date: Date)
    func clear()
}

protocol QuizSessionStoring {
    func load() -> QuizSession?
    func loadSummary() -> QuizSessionSummary?
    func save(_ session: QuizSession)
    func clear()
}

protocol FormulaFavoriteStoring {
    func load() -> Set<String>
    func save(_ ids: Set<String>)
}

protocol QuestionReportStoring {
    func loadReports() -> [QuestionReport]
    func saveReport(_ report: QuestionReport)
    func saveReports(_ reports: [QuestionReport])
    func clear()
}

protocol QuestionDiskStoring {
    func load() -> [CFAQuestion]
    func save(_ questions: [CFAQuestion])
    func clear()
}

protocol CategoryGoalStoring {
    func loadGoals() -> [String: Int]
    func saveGoals(_ goals: [String: Int])
}

protocol WeeklyGoalStoring {
    var weeklyQuestionGoal: Int { get set }
}

struct AppDependencies {
    let questionRepository: QuestionRepository
    let statsStore: StatsStoring
    let historyStore: QuestionHistoryStoring
    let sessionStore: QuizSessionStoring
    let formulaFavoriteStore: FormulaFavoriteStoring
    let questionReportStore: QuestionReportStoring
    let questionDiskStore: QuestionDiskStoring
    let weeklyGoalStore: WeeklyGoalStoring
    let categoryGoalStore: CategoryGoalStoring

    static let shared = AppDependencies(
        questionRepository: HybridQuestionRepository(),
        statsStore: StatsStore.shared,
        historyStore: QuestionHistoryStore.shared,
        sessionStore: QuizSessionStore.shared,
        formulaFavoriteStore: FormulaFavoriteStore.shared,
        questionReportStore: QuestionReportStore.shared,
        questionDiskStore: QuestionDiskStore.shared,
        weeklyGoalStore: WeeklyGoalStore.shared,
        categoryGoalStore: CategoryGoalStore.shared
    )
}

extension StatsStore: StatsStoring {}
extension QuestionHistoryStore: QuestionHistoryStoring {}
extension QuizSessionStore: QuizSessionStoring {}
extension FormulaFavoriteStore: FormulaFavoriteStoring {}
extension QuestionReportStore: QuestionReportStoring {}
extension QuestionDiskStore: QuestionDiskStoring {}
extension CategoryGoalStore: CategoryGoalStoring {}
extension WeeklyGoalStore: WeeklyGoalStoring {}
