import Foundation
import Combine

@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var attempts: [QuizAttempt] = []
    @Published private(set) var availableCategories: [CFACategory] = []
    @Published var weeklyGoal: Int {
        didSet {
            let clamped = max(0, weeklyGoal)
            if clamped != weeklyGoal {
                weeklyGoal = clamped
                return
            }
            weeklyGoalStore.weeklyQuestionGoal = clamped
        }
    }
    @Published private var weeklyCategoryGoals: [String: Int]

    struct AttemptPoint: Identifiable {
        let id = UUID()
        let date: Date
        let accuracy: Double
    }

    struct CategoryPoint: Identifiable {
        let id = UUID()
        let category: CFACategory
        let accuracy: Double
    }

    struct CategoryCount: Identifiable {
        let id = UUID()
        let category: CFACategory
        let count: Int
    }

    struct CategoryCoverage: Identifiable {
        let id = UUID()
        let category: CFACategory
        let seen: Int
        let total: Int
        let progress: Double
    }

    struct SubcategoryCoverage: Identifiable {
        let id: String
        let category: CFACategory
        let subcategory: String
        let seen: Int
        let total: Int
        let progress: Double
    }

    struct WeeklyGoalAlert: Identifiable {
        let id: String
        let category: CFACategory
        let answered: Int
        let goal: Int

        var remaining: Int { max(0, goal - answered) }
    }

    struct SubcategoryProgress: Identifiable {
        let id: String
        let subcategory: String
        let attempted: Int
        let total: Int
        let accuracy: Double
        let progress: Double
    }

    struct WeaknessFocus: Identifiable {
        let id: String
        let category: CFACategory
        let attempted: Int
        let accuracy: Double
    }

    private let repo: QuestionRepository
    private let statsStore: StatsStoring
    private let historyStore: QuestionHistoryStoring
    private let weeklyGoalStore: WeeklyGoalStoring
    private let categoryGoalStore: CategoryGoalStoring
    private var allQuestions: [CFAQuestion] = []
    private var historyById: [String: QuestionHistory] = [:]

    private var overallAccuracyCache: Double = 0
    private var bestScorePctCache: Double = 0
    private var averageSecondsPerQuestionCache: Double = 0
    private var weeklyQuestionsAnsweredCache: Int = 0
    private var weeklyByCategoryCache: [CFACategory: Int] = [:]
    private var streakDaysCache: Int = 0
    private var accuracySeriesCache: [AttemptPoint] = []
    private var categoryAccuracyCache: [CategoryPoint] = []
    private var categoryCountsCache: [CategoryCount] = []
    private var categoryCoverageCache: [CategoryCoverage] = []
    private var subcategoryCoverageCache: [SubcategoryCoverage] = []
    private var subcategoryProgressCache: [SubcategoryProgress] = []
    private var weaknessFocusCache: [WeaknessFocus] = []

    @MainActor
    convenience init() {
        self.init(
            repo: AppDependencies.shared.questionRepository,
            statsStore: AppDependencies.shared.statsStore,
            historyStore: AppDependencies.shared.historyStore,
            weeklyGoalStore: AppDependencies.shared.weeklyGoalStore,
            categoryGoalStore: AppDependencies.shared.categoryGoalStore
        )
    }

    @MainActor
    init(
        repo: QuestionRepository,
        statsStore: StatsStoring,
        historyStore: QuestionHistoryStoring,
        weeklyGoalStore: WeeklyGoalStoring,
        categoryGoalStore: CategoryGoalStoring
    ) {
        self.repo = repo
        self.statsStore = statsStore
        self.historyStore = historyStore
        self.weeklyGoalStore = weeklyGoalStore
        self.categoryGoalStore = categoryGoalStore
        self.weeklyGoal = weeklyGoalStore.weeklyQuestionGoal
        self.weeklyCategoryGoals = categoryGoalStore.loadGoals()
        loadCatalog()
        refresh()
    }

    func refresh() {
        attempts = statsStore.loadAttempts()
        historyById = historyStore.loadAll()
        loadCatalog()
        recomputeDerivedData()
    }

    func clearAll() {
        statsStore.clear()
        historyStore.clear()
        refresh()
    }

    var totalAttempts: Int { attempts.count }
    var overallAccuracy: Double { overallAccuracyCache }
    var bestScorePct: Double { bestScorePctCache }
    var averageSecondsPerQuestion: Double { averageSecondsPerQuestionCache }
    var weeklyQuestionsAnswered: Int { weeklyQuestionsAnsweredCache }

    var weeklyProgress: Double {
        guard weeklyGoal > 0 else { return 0 }
        return min(1, Double(weeklyQuestionsAnsweredCache) / Double(weeklyGoal))
    }

    func weeklyGoal(for category: CFACategory) -> Int {
        weeklyCategoryGoals[category.rawValue] ?? 0
    }

    func setWeeklyGoal(_ goal: Int, for category: CFACategory) {
        let clamped = max(0, goal)
        weeklyCategoryGoals[category.rawValue] = clamped
        categoryGoalStore.saveGoals(weeklyCategoryGoals)
    }

    var weeklyGoalAlerts: [WeeklyGoalAlert] {
        let alerts = availableCategories.compactMap { cat -> WeeklyGoalAlert? in
            let goal = weeklyGoal(for: cat)
            guard goal > 0 else { return nil }
            let answered = weeklyByCategoryCache[cat] ?? 0
            guard answered < goal else { return nil }
            return WeeklyGoalAlert(id: cat.rawValue, category: cat, answered: answered, goal: goal)
        }
        return alerts.sorted { lhs, rhs in
            if lhs.remaining == rhs.remaining {
                return lhs.category.rawValue < rhs.category.rawValue
            }
            return lhs.remaining > rhs.remaining
        }
    }

    var streakDays: Int { streakDaysCache }
    var accuracySeries: [AttemptPoint] { accuracySeriesCache }
    var categoryAccuracy: [CategoryPoint] { categoryAccuracyCache }
    var categoryCounts: [CategoryCount] { categoryCountsCache }
    var categoryCoverage: [CategoryCoverage] { categoryCoverageCache }
    var subcategoryCoverage: [SubcategoryCoverage] { subcategoryCoverageCache }
    var subcategoryProgress: [SubcategoryProgress] { subcategoryProgressCache }
    var weaknessFocus: [WeaknessFocus] { weaknessFocusCache }

    var targetedQuestionCount: Int {
        guard !weaknessFocusCache.isEmpty else { return 20 }
        return max(10, min(30, weaknessFocusCache.count * 8))
    }

    func weeklyAnswered(for category: CFACategory) -> Int {
        weeklyByCategoryCache[category] ?? 0
    }

    func weeklyProgress(for category: CFACategory) -> Double {
        let goal = weeklyGoal(for: category)
        guard goal > 0 else { return 0 }
        return min(1, Double(weeklyAnswered(for: category)) / Double(goal))
    }

    private func loadCatalog() {
        do {
            allQuestions = try repo.loadAllQuestions()
        } catch {
            allQuestions = []
            AppLogger.warning("StatsViewModel failed to load catalog: \(error.localizedDescription)")
        }
        availableCategories = Array(Set(allQuestions.map { $0.category }))
            .sorted { $0.rawValue < $1.rawValue }
    }

    private func recomputeDerivedData() {
        let totalAnswered = attempts.reduce(0) { $0 + $1.total }
        let totalCorrect = attempts.reduce(0) { $0 + $1.score }
        overallAccuracyCache = totalAnswered == 0 ? 0 : Double(totalCorrect) / Double(totalAnswered)

        bestScorePctCache = attempts
            .map { Double($0.score) / Double(max(1, $0.total)) }
            .max() ?? 0

        let totalSeconds = attempts.reduce(0) { $0 + $1.durationSeconds }
        averageSecondsPerQuestionCache = totalAnswered == 0 ? 0 : Double(totalSeconds) / Double(totalAnswered)

        let calendar = Calendar.current
        if let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) {
            var weeklyByCategory: [CFACategory: Int] = [:]
            var weeklyAnswered = 0
            for attempt in attempts where attempt.date >= interval.start && attempt.date < interval.end {
                weeklyAnswered += attempt.total
                for (cat, result) in attempt.perCategory {
                    weeklyByCategory[cat, default: 0] += result.total
                }
            }
            weeklyQuestionsAnsweredCache = weeklyAnswered
            weeklyByCategoryCache = weeklyByCategory
        } else {
            weeklyQuestionsAnsweredCache = 0
            weeklyByCategoryCache = [:]
        }

        let activeDays = Set(attempts.map { calendar.startOfDay(for: $0.date) })
        if let latest = activeDays.max(), calendar.isDateInToday(latest) {
            var streak = 0
            var day = latest
            while activeDays.contains(day) {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = previous
            }
            streakDaysCache = streak
        } else {
            streakDaysCache = 0
        }

        accuracySeriesCache = attempts
            .sorted { $0.date < $1.date }
            .map { AttemptPoint(date: $0.date, accuracy: Double($0.score) / Double(max(1, $0.total))) }

        var catAccuracyTotals: [CFACategory: (correct: Int, total: Int)] = [:]
        for attempt in attempts {
            for (cat, result) in attempt.perCategory {
                catAccuracyTotals[cat, default: (0, 0)].correct += result.correct
                catAccuracyTotals[cat, default: (0, 0)].total += result.total
            }
        }
        categoryAccuracyCache = catAccuracyTotals.map { cat, tuple in
            let acc = tuple.total == 0 ? 0 : Double(tuple.correct) / Double(tuple.total)
            return CategoryPoint(category: cat, accuracy: acc)
        }.sorted { $0.category.rawValue < $1.category.rawValue }

        let allWeaknesses = catAccuracyTotals.map { cat, tuple in
            let acc = tuple.total == 0 ? 0 : Double(tuple.correct) / Double(tuple.total)
            return WeaknessFocus(
                id: cat.rawValue,
                category: cat,
                attempted: tuple.total,
                accuracy: acc
            )
        }
        .filter { $0.attempted > 0 }
        .sorted { lhs, rhs in
            if lhs.accuracy == rhs.accuracy {
                if lhs.attempted == rhs.attempted {
                    return lhs.category.rawValue < rhs.category.rawValue
                }
                return lhs.attempted > rhs.attempted
            }
            return lhs.accuracy < rhs.accuracy
        }

        let meaningful = allWeaknesses.filter { $0.attempted >= 3 }
        weaknessFocusCache = Array((meaningful.isEmpty ? allWeaknesses : meaningful).prefix(3))

        var categoryCounts: [CFACategory: Int] = [:]
        for q in allQuestions {
            categoryCounts[q.category, default: 0] += 1
        }
        categoryCountsCache = availableCategories.map { cat in
            CategoryCount(category: cat, count: categoryCounts[cat] ?? 0)
        }

        let seenIds = Set(historyById.keys)
        var categoryCoverageTotals: [CFACategory: (seen: Int, total: Int)] = [:]
        for q in allQuestions {
            categoryCoverageTotals[q.category, default: (0, 0)].total += 1
            if seenIds.contains(q.id) {
                categoryCoverageTotals[q.category, default: (0, 0)].seen += 1
            }
        }
        categoryCoverageCache = availableCategories.map { cat in
            let entry = categoryCoverageTotals[cat] ?? (0, 0)
            let progress = entry.total == 0 ? 0 : Double(entry.seen) / Double(entry.total)
            return CategoryCoverage(category: cat, seen: entry.seen, total: entry.total, progress: progress)
        }

        struct SubKey: Hashable {
            let category: CFACategory
            let subcategory: String
        }
        var subCoverageTotals: [SubKey: (seen: Int, total: Int)] = [:]
        for q in allQuestions {
            let sub = (q.subcategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sub.isEmpty else { continue }
            let key = SubKey(category: q.category, subcategory: sub)
            subCoverageTotals[key, default: (0, 0)].total += 1
            if seenIds.contains(q.id) {
                subCoverageTotals[key, default: (0, 0)].seen += 1
            }
        }
        subcategoryCoverageCache = subCoverageTotals.map { key, entry in
            let progress = entry.total == 0 ? 0 : Double(entry.seen) / Double(entry.total)
            return SubcategoryCoverage(
                id: "\(key.category.rawValue)::\(key.subcategory)",
                category: key.category,
                subcategory: key.subcategory,
                seen: entry.seen,
                total: entry.total,
                progress: progress
            )
        }.sorted {
            if $0.category.rawValue != $1.category.rawValue {
                return $0.category.rawValue < $1.category.rawValue
            }
            return $0.subcategory.localizedCaseInsensitiveCompare($1.subcategory) == .orderedAscending
        }

        var totalBySub: [String: Int] = [:]
        for q in allQuestions {
            let sub = (q.subcategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sub.isEmpty else { continue }
            totalBySub[sub, default: 0] += 1
        }
        var attemptedBySub: [String: (correct: Int, total: Int)] = [:]
        for attempt in attempts {
            guard let perSub = attempt.perSubcategory else { continue }
            for (rawSub, result) in perSub {
                let sub = rawSub.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sub.isEmpty else { continue }
                attemptedBySub[sub, default: (0, 0)].correct += result.correct
                attemptedBySub[sub, default: (0, 0)].total += result.total
            }
        }
        let subKeys = Set(totalBySub.keys).union(attemptedBySub.keys)
        subcategoryProgressCache = subKeys.compactMap { sub -> SubcategoryProgress? in
            let total = totalBySub[sub] ?? attemptedBySub[sub]?.total ?? 0
            let attemptedTotal = attemptedBySub[sub]?.total ?? 0
            let attemptedCorrect = attemptedBySub[sub]?.correct ?? 0
            if total == 0 && attemptedTotal == 0 {
                return nil
            }
            let accuracy = attemptedTotal == 0 ? 0 : Double(attemptedCorrect) / Double(attemptedTotal)
            let completion = total == 0 ? 0 : Double(attemptedTotal) / Double(total)
            return SubcategoryProgress(
                id: sub,
                subcategory: sub,
                attempted: attemptedTotal,
                total: total,
                accuracy: accuracy,
                progress: completion
            )
        }.sorted {
            if $0.progress == $1.progress {
                return $0.subcategory.localizedCaseInsensitiveCompare($1.subcategory) == .orderedAscending
            }
            return $0.progress < $1.progress
        }
    }
}
