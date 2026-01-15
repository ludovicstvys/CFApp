import Foundation

struct QuizAttempt: Identifiable, Codable {
    let id: String
    let date: Date
    let level: CFALevel
    let mode: QuizMode
    let categories: [CFACategory]
    let score: Int
    let total: Int
    let durationSeconds: Int
    let perCategory: [CFACategory: CategoryResult]
    let perSubcategory: [String: CategoryResult]?   // optionnel

    struct CategoryResult: Codable {
        let correct: Int
        let total: Int
    }

    init(
        id: String = UUID().uuidString,
        date: Date = Date(),
        level: CFALevel,
        mode: QuizMode,
        categories: [CFACategory],
        score: Int,
        total: Int,
        durationSeconds: Int,
        perCategory: [CFACategory: CategoryResult],
        perSubcategory: [String: CategoryResult]? = nil
    ) {
        self.id = id
        self.date = date
        self.level = level
        self.mode = mode
        self.categories = categories
        self.score = score
        self.total = total
        self.durationSeconds = durationSeconds
        self.perCategory = perCategory
        self.perSubcategory = perSubcategory
    }
}
