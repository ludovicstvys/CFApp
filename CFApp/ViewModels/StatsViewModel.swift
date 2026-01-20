import Foundation
import Combine

@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var attempts: [QuizAttempt] = []
    @Published private(set) var availableCategories: [CFACategory] = []
    @Published var weeklyGoal: Int = WeeklyGoalStore.shared.weeklyQuestionGoal {
        didSet {
            let clamped = max(0, weeklyGoal)
            if clamped != weeklyGoal {
                weeklyGoal = clamped
                return
            }
            WeeklyGoalStore.shared.weeklyQuestionGoal = clamped
        }
    }
    @Published private var weeklyCategoryGoals: [String: Int] = CategoryGoalStore.shared.loadGoals()

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

    private let repo: QuestionRepository
    private var allQuestions: [CFAQuestion] = []
    private var historyById: [String: QuestionHistory] = [:]

    init(repo: QuestionRepository = HybridQuestionRepository()) {
        self.repo = repo
        loadCatalog()
    }

    func refresh() {
        attempts = StatsStore.shared.loadAttempts()
        historyById = QuestionHistoryStore.shared.loadAll()
        loadCatalog()
    }

    func clearAll() {
        StatsStore.shared.clear()
        QuestionHistoryStore.shared.clear()
        refresh()
    }

    var totalAttempts: Int { attempts.count }

    var overallAccuracy: Double {
        let total = attempts.reduce(0) { $0 + $1.total }
        let score = attempts.reduce(0) { $0 + $1.score }
        guard total > 0 else { return 0 }
        return Double(score) / Double(total)
    }

    var bestScorePct: Double {
        guard let best = attempts.map({ Double($0.score) / Double(max(1, $0.total)) }).max() else { return 0 }
        return best
    }

    var averageSecondsPerQuestion: Double {
        let totalQuestions = attempts.reduce(0) { $0 + $1.total }
        let totalSeconds = attempts.reduce(0) { $0 + $1.durationSeconds }
        guard totalQuestions > 0 else { return 0 }
        return Double(totalSeconds) / Double(totalQuestions)
    }

    var weeklyQuestionsAnswered: Int {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return attempts
            .filter { $0.date >= interval.start && $0.date < interval.end }
            .reduce(0) { $0 + $1.total }
    }

    var weeklyProgress: Double {
        guard weeklyGoal > 0 else { return 0 }
        return min(1, Double(weeklyQuestionsAnswered) / Double(weeklyGoal))
    }

    func weeklyGoal(for category: CFACategory) -> Int {
        weeklyCategoryGoals[category.rawValue] ?? 0
    }

    func setWeeklyGoal(_ goal: Int, for category: CFACategory) {
        let clamped = max(0, goal)
        weeklyCategoryGoals[category.rawValue] = clamped
        CategoryGoalStore.shared.saveGoals(weeklyCategoryGoals)
    }

    var weeklyGoalAlerts: [WeeklyGoalAlert] {
        let byCategory = weeklyQuestionsByCategory()
        let alerts = availableCategories.compactMap { cat -> WeeklyGoalAlert? in
            let goal = weeklyGoal(for: cat)
            guard goal > 0 else { return nil }
            let answered = byCategory[cat] ?? 0
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

    var streakDays: Int {
        let calendar = Calendar.current
        let days = Set(attempts.map { calendar.startOfDay(for: $0.date) })
        guard let latest = days.max() else { return 0 }
        guard calendar.isDateInToday(latest) else { return 0 }

        var streak = 0
        var day = latest
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    var accuracySeries: [AttemptPoint] {
        attempts
            .sorted { $0.date < $1.date }
            .map { AttemptPoint(date: $0.date, accuracy: Double($0.score) / Double(max(1, $0.total))) }
    }

    var categoryAccuracy: [CategoryPoint] {
        var totals: [CFACategory: (correct: Int, total: Int)] = [:]
        for attempt in attempts {
            for (cat, result) in attempt.perCategory {
                totals[cat, default: (0, 0)].0 += result.correct
                totals[cat, default: (0, 0)].1 += result.total
            }
        }
        return totals.map { cat, tuple in
            let acc = tuple.total == 0 ? 0 : Double(tuple.correct) / Double(tuple.total)
            return CategoryPoint(category: cat, accuracy: acc)
        }.sorted { $0.category.rawValue < $1.category.rawValue }
    }

    var categoryCounts: [CategoryCount] {
        var totals: [CFACategory: Int] = [:]
        for q in allQuestions {
            totals[q.category, default: 0] += 1
        }
        return availableCategories.map { cat in
            CategoryCount(category: cat, count: totals[cat] ?? 0)
        }
    }

    var categoryCoverage: [CategoryCoverage] {
        var totals: [CFACategory: (seen: Int, total: Int)] = [:]
        let seenIds = Set(historyById.keys)
        for q in allQuestions {
            var entry = totals[q.category, default: (0, 0)]
            entry.total += 1
            if seenIds.contains(q.id) {
                entry.seen += 1
            }
            totals[q.category] = entry
        }
        return availableCategories.map { cat in
            let entry = totals[cat] ?? (0, 0)
            let progress = entry.total == 0 ? 0 : Double(entry.seen) / Double(entry.total)
            return CategoryCoverage(category: cat, seen: entry.seen, total: entry.total, progress: progress)
        }
    }

    var subcategoryCoverage: [SubcategoryCoverage] {
        struct Key: Hashable {
            let category: CFACategory
            let subcategory: String
        }
        var totals: [Key: (seen: Int, total: Int)] = [:]
        let seenIds = Set(historyById.keys)

        for q in allQuestions {
            let sub = (q.subcategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sub.isEmpty else { continue }
            let key = Key(category: q.category, subcategory: sub)
            var entry = totals[key, default: (0, 0)]
            entry.total += 1
            if seenIds.contains(q.id) {
                entry.seen += 1
            }
            totals[key] = entry
        }

        let items = totals.map { key, entry -> SubcategoryCoverage in
            let progress = entry.total == 0 ? 0 : Double(entry.seen) / Double(entry.total)
            return SubcategoryCoverage(
                id: "\(key.category.rawValue)::\(key.subcategory)",
                category: key.category,
                subcategory: key.subcategory,
                seen: entry.seen,
                total: entry.total,
                progress: progress
            )
        }

        return items.sorted {
            if $0.category.rawValue != $1.category.rawValue {
                return $0.category.rawValue < $1.category.rawValue
            }
            return $0.subcategory.localizedCaseInsensitiveCompare($1.subcategory) == .orderedAscending
        }
    }

    var subcategoryProgress: [SubcategoryProgress] {
        let totals = totalQuestionsBySubcategory()
        let attempted = attemptedBySubcategory()
        let keys = Set(totals.keys).union(attempted.keys)

        let progress = keys.compactMap { sub -> SubcategoryProgress? in
            let total = totals[sub] ?? attempted[sub]?.total ?? 0
            let attemptedTotal = attempted[sub]?.total ?? 0
            let attemptedCorrect = attempted[sub]?.correct ?? 0
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
        }

        return progress.sorted {
            if $0.progress == $1.progress {
                return $0.subcategory.localizedCaseInsensitiveCompare($1.subcategory) == .orderedAscending
            }
            return $0.progress < $1.progress
        }
    }

    func weeklyAnswered(for category: CFACategory) -> Int {
        weeklyQuestionsByCategory()[category] ?? 0
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
        }
        availableCategories = Array(Set(allQuestions.map { $0.category }))
            .sorted { $0.rawValue < $1.rawValue }
    }

    private func totalQuestionsBySubcategory() -> [String: Int] {
        var totals: [String: Int] = [:]
        for q in allQuestions {
            let sub = (q.subcategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sub.isEmpty else { continue }
            totals[sub, default: 0] += 1
        }
        return totals
    }

    private func attemptedBySubcategory() -> [String: (correct: Int, total: Int)] {
        var totals: [String: (correct: Int, total: Int)] = [:]
        for attempt in attempts {
            guard let perSub = attempt.perSubcategory else { continue }
            for (rawSub, result) in perSub {
                let sub = rawSub.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sub.isEmpty else { continue }
                totals[sub, default: (0, 0)].correct += result.correct
                totals[sub, default: (0, 0)].total += result.total
            }
        }
        return totals
    }

    private func weeklyQuestionsByCategory() -> [CFACategory: Int] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [:] }
        var totals: [CFACategory: Int] = [:]
        for attempt in attempts where attempt.date >= interval.start && attempt.date < interval.end {
            for (cat, result) in attempt.perCategory {
                totals[cat, default: 0] += result.total
            }
        }
        return totals
    }
}
