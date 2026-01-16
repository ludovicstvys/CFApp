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
        rng: inout R
    ) -> [PreparedQuestion] {

        let filtered = questions.filter { q in
            guard q.level == config.level else { return false }

            if config.mode == .random {
                return true
            }

            guard config.categories.contains(q.category) else { return false }

            if !config.subcategories.isEmpty {
                let sub = (q.subcategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return config.subcategories.contains(sub)
            }
            return true
        }

        let pool = filtered.shuffled(using: &rng)
        let n = min(config.numberOfQuestions, pool.count)
        let selected = Array(pool.prefix(n))

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
}
