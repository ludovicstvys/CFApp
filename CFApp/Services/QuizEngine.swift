import Foundation

/// Selection/shuffle engine for quiz questions.
struct QuizEngine {

    /// Question ready for display.
    /// If `shuffleAnswers = true`, choices are shuffled and correct indices are remapped.
    struct PreparedQuestion: Identifiable, Hashable {
        let id: String
        let original: CFAQuestion
        let stem: String
        let choices: [String]
        let correctIndices: [Int]
    }

    func prepare<R: RandomNumberGenerator>(
        questions: [CFAQuestion],
        config: QuizConfig,
        historyById: [String: QuestionHistory] = [:],
        rng: inout R
    ) -> [PreparedQuestion] {

        let validQuestions = questions.filter { q in
            guard q.choices.count >= 2 else { return false }
            guard !q.correctIndices.isEmpty else { return false }
            let maxIndex = q.choices.count - 1
            return q.correctIndices.allSatisfy { (0...maxIndex).contains($0) }
        }

        let allowAllCategories = config.categories.isEmpty

        let filtered = validQuestions.filter { q in
            guard q.level == config.level else { return false }

            if config.mode == .random {
                return true
            }

            if !allowAllCategories, !config.categories.contains(q.category) {
                return false
            }

            if !config.subcategories.isEmpty {
                let sub = (q.subcategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return config.subcategories.contains(sub)
            }
            return true
        }

        let n = min(config.numberOfQuestions, filtered.count)
        let selected: [CFAQuestion]

        if config.mode == .spaced {
            let now = Date()
            var scored = filtered.map { q in
                let history = historyById[q.id]
                return (question: q, weight: srsWeight(for: q, history: history, now: now))
            }
            scored.shuffle(using: &rng)
            scored.sort { $0.weight > $1.weight }
            selected = scored.prefix(n).map { $0.question }
        } else {
            let pool = filtered.shuffled(using: &rng)
            selected = Array(pool.prefix(n))
        }

        return selected.map { q in
            if config.shuffleAnswers {
                var pairs = q.choices.enumerated().map { (idx, text) in (idx, text) }
                pairs.shuffle(using: &rng)

                let newChoices = pairs.map { $0.1 }
                let newCorrect = q.correctIndices.compactMap { oldIdx in
                    pairs.firstIndex(where: { $0.0 == oldIdx })
                }.sorted()

                return PreparedQuestion(
                    id: q.id,
                    original: q,
                    stem: q.stem,
                    choices: newChoices,
                    correctIndices: newCorrect
                )
            } else {
                return PreparedQuestion(
                    id: q.id,
                    original: q,
                    stem: q.stem,
                    choices: q.choices,
                    correctIndices: q.correctIndices.sorted()
                )
            }
        }
    }

    private func srsWeight(for question: CFAQuestion, history: QuestionHistory?, now: Date) -> Double {
        guard let history else {
            // Never seen question: still high priority, but below urgent overdue items.
            return 4.0
        }

        let dueComponent: Double
        if let nextDue = history.nextDueAt {
            let daysToDue = (nextDue.timeIntervalSince(now)) / 86_400
            if daysToDue <= 0 {
                // Overdue questions get strong boost.
                dueComponent = 4.0 + min(4.0, abs(daysToDue) / 2.0)
            } else {
                // Not due yet: low priority.
                dueComponent = max(0.2, 1.0 - min(1.0, daysToDue / 7.0))
            }
        } else {
            dueComponent = 2.0
        }

        let accuracyPenalty = (1.0 - history.accuracy) * 2.0
        let incorrectBoost = min(3.0, Double(history.incorrectStreak) * 1.25)
        let lowExposureBoost = history.seenCount <= 2 ? 1.0 : 0.0
        let difficultyHint = Double(question.difficulty ?? 0) * 0.05

        return dueComponent + accuracyPenalty + incorrectBoost + lowExposureBoost + difficultyHint
    }
}
