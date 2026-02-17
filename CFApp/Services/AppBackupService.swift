import Foundation

struct AppBackupPayload: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let attempts: [QuizAttempt]
    let questionHistory: [String: QuestionHistory]
    let questionReports: [QuestionReport]
    let formulaFavoriteIDs: [String]
    let weeklyGoal: Int
    let categoryGoals: [String: Int]
    let currentSession: QuizSession?
    let importedQuestions: [CFAQuestion]
    let themePreferenceRawValue: Int
}

struct AppBackupImportSummary {
    let attempts: Int
    let historyItems: Int
    let reports: Int
    let favoriteFormulas: Int
    let importedQuestions: Int
}

enum AppBackupError: LocalizedError {
    case invalidBackupFormat

    var errorDescription: String? {
        switch self {
        case .invalidBackupFormat:
            return "Format de sauvegarde invalide."
        }
    }
}

final class AppBackupService {
    static let shared = AppBackupService()
    private let currentSchemaVersion = 1
    private let themeKey = "cfaquiz.themePreference"

    private let statsStore: StatsStoring
    private let historyStore: QuestionHistoryStoring
    private let reportStore: QuestionReportStoring
    private let favoriteStore: FormulaFavoriteStoring
    private let weeklyGoalStore: WeeklyGoalStoring
    private let categoryGoalStore: CategoryGoalStoring
    private let sessionStore: QuizSessionStoring
    private let questionDiskStore: QuestionDiskStoring
    private let defaults: UserDefaults

    init(
        statsStore: StatsStoring = AppDependencies.shared.statsStore,
        historyStore: QuestionHistoryStoring = AppDependencies.shared.historyStore,
        reportStore: QuestionReportStoring = AppDependencies.shared.questionReportStore,
        favoriteStore: FormulaFavoriteStoring = AppDependencies.shared.formulaFavoriteStore,
        weeklyGoalStore: WeeklyGoalStoring = AppDependencies.shared.weeklyGoalStore,
        categoryGoalStore: CategoryGoalStoring = AppDependencies.shared.categoryGoalStore,
        sessionStore: QuizSessionStoring = AppDependencies.shared.sessionStore,
        questionDiskStore: QuestionDiskStoring = AppDependencies.shared.questionDiskStore,
        defaults: UserDefaults = .standard
    ) {
        self.statsStore = statsStore
        self.historyStore = historyStore
        self.reportStore = reportStore
        self.favoriteStore = favoriteStore
        self.weeklyGoalStore = weeklyGoalStore
        self.categoryGoalStore = categoryGoalStore
        self.sessionStore = sessionStore
        self.questionDiskStore = questionDiskStore
        self.defaults = defaults
    }

    func exportBackupData() throws -> Data {
        let payload = AppBackupPayload(
            schemaVersion: currentSchemaVersion,
            exportedAt: Date(),
            attempts: statsStore.loadAttempts(),
            questionHistory: historyStore.loadAll(),
            questionReports: reportStore.loadReports(),
            formulaFavoriteIDs: Array(favoriteStore.load()).sorted(),
            weeklyGoal: weeklyGoalStore.weeklyQuestionGoal,
            categoryGoals: categoryGoalStore.loadGoals(),
            currentSession: sessionStore.load(),
            importedQuestions: questionDiskStore.load(),
            themePreferenceRawValue: defaults.integer(forKey: themeKey)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    func importBackupData(_ data: Data) throws -> AppBackupImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(AppBackupPayload.self, from: data) else {
            throw AppBackupError.invalidBackupFormat
        }

        statsStore.saveAllAttempts(payload.attempts)
        historyStore.save(payload.questionHistory)
        reportStore.saveReports(payload.questionReports)
        favoriteStore.save(Set(payload.formulaFavoriteIDs))
        weeklyGoalStore.weeklyQuestionGoal = max(0, payload.weeklyGoal)
        categoryGoalStore.saveGoals(payload.categoryGoals)
        if let session = payload.currentSession {
            sessionStore.save(session)
        } else {
            sessionStore.clear()
        }
        questionDiskStore.save(payload.importedQuestions)
        defaults.set(payload.themePreferenceRawValue, forKey: themeKey)

        return AppBackupImportSummary(
            attempts: payload.attempts.count,
            historyItems: payload.questionHistory.count,
            reports: payload.questionReports.count,
            favoriteFormulas: payload.formulaFavoriteIDs.count,
            importedQuestions: payload.importedQuestions.count
        )
    }
}
