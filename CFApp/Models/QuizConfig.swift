import Foundation

struct QuizConfig: Hashable, Codable {
    let level: CFALevel
    let mode: QuizMode
    let categories: Set<CFACategory>
    /// If empty => no subcategory filter.
    let subcategories: Set<String>
    let numberOfQuestions: Int
    let shuffleAnswers: Bool
    let timeLimitSeconds: Int?

    var usesCountdown: Bool {
        mode == .test || mode == .mock
    }

    var effectiveTimeLimitSeconds: Int? {
        if mode == .mock {
            return timeLimitSeconds ?? (180 * 60)
        }
        return timeLimitSeconds
    }

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
