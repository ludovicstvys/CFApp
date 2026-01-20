import Foundation

/// Moteur de sélection / mélange des questions.
/// - Filtre par niveau/catégories/sous-catégories
/// - Sélectionne un nombre de questions
/// - (optionnellement) mélange l'ordre des réponses
struct QuizEngine {

    /// Question prête à être affichée.
    /// Si shuffleAnswers = true, on mélange les choices et on remappe correctIndices.
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
            guard q.choices.count >= 2 else {
                #if DEBUG
                print("QuizEngine: question ignored (choices<2): \(q.id)")
                #endif
                return false
            }
            guard !q.correctIndices.isEmpty else {
                #if DEBUG
                print("QuizEngine: question ignored (no correctIndices): \(q.id)")
                #endif
                return false
            }
            let maxIndex = q.choices.count - 1
            let ok = q.correctIndices.allSatisfy { (0...maxIndex).contains($0) }
            if !ok {
                #if DEBUG
                print("QuizEngine: question ignored (correctIndices out of bounds): \(q.id)")
                #endif
            }
            return ok
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
            return 4.0
        }

        if history.incorrectStreak > 0 {
            let streakBoost = min(2.0, Double(history.incorrectStreak))
            let daysSince = daysSince(history.lastAttemptAt, now: now)
            return 3.5 + streakBoost + min(2.0, daysSince / 2.0)
        }

        let interval = srsIntervalDays(for: history.correctStreak)
        let daysSinceCorrect = daysSince(history.lastCorrectAt, now: now)
        if daysSinceCorrect >= interval {
            return 2.5 + min(2.5, daysSinceCorrect / max(1.0, interval))
        }

        return 0.5
    }

    private func srsIntervalDays(for correctStreak: Int) -> Double {
        switch correctStreak {
        case 0: return 1
        case 1: return 2
        case 2: return 4
        case 3: return 7
        case 4: return 14
        default: return 30
        }
    }

    private func daysSince(_ date: Date?, now: Date) -> Double {
        guard let date else { return 30 }
        let seconds = now.timeIntervalSince(date)
        return max(0, seconds / 86_400)
    }
}
