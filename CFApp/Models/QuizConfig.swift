import Foundation

struct QuizConfig: Hashable, Codable {
    let level: CFALevel
    let mode: QuizMode
    let categories: Set<CFACategory>
    /// Si vide => toutes les sous-catégories (pas de filtre)
    let subcategories: Set<String>
    let numberOfQuestions: Int
    let shuffleAnswers: Bool
    let timeLimitSeconds: Int? // surtout pour mode Test (optionnel)

    static func `default`() -> QuizConfig {
        QuizConfig(
            level: .level1,
            mode: .revision,
            categories: [],
            subcategories: [],
            numberOfQuestions: 20,
            shuffleAnswers: false,
            timeLimitSeconds: nil
        )
    }
}
