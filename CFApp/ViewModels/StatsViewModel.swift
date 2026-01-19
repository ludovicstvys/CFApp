import Foundation
import Combine

@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var attempts: [QuizAttempt] = []
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

    init(repo: QuestionRepository = HybridQuestionRepository()) {
        self.repo = repo
        loadCatalog()
    }

    func refresh() {
        attempts = StatsStore.shared.loadAttempts()
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

    private func loadCatalog() {
        do {
            allQuestions = try repo.loadAllQuestions()
        } catch {
            allQuestions = []
        }
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
}
