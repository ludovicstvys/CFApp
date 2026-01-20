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

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case level
        case mode
        case categories
        case score
        case total
        case durationSeconds
        case perCategory
        case perSubcategory
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        level = try c.decode(CFALevel.self, forKey: .level)
        mode = try c.decode(QuizMode.self, forKey: .mode)
        score = try c.decode(Int.self, forKey: .score)
        total = try c.decode(Int.self, forKey: .total)
        durationSeconds = try c.decode(Int.self, forKey: .durationSeconds)
        perSubcategory = try c.decodeIfPresent([String: CategoryResult].self, forKey: .perSubcategory)

        if let rawCats = try? c.decode([String].self, forKey: .categories) {
            categories = rawCats.map(CFACategory.init)
        } else {
            categories = try c.decode([CFACategory].self, forKey: .categories)
        }

        if let rawDict = try? c.decode([String: CategoryResult].self, forKey: .perCategory) {
            perCategory = Dictionary(uniqueKeysWithValues: rawDict.map { key, value in
                (CFACategory(key), value)
            })
        } else {
            perCategory = try c.decode([CFACategory: CategoryResult].self, forKey: .perCategory)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(level, forKey: .level)
        try c.encode(mode, forKey: .mode)
        try c.encode(categories.map { $0.rawValue }, forKey: .categories)
        try c.encode(score, forKey: .score)
        try c.encode(total, forKey: .total)
        try c.encode(durationSeconds, forKey: .durationSeconds)
        let rawPerCategory = Dictionary(uniqueKeysWithValues: perCategory.map { key, value in
            (key.rawValue, value)
        })
        try c.encode(rawPerCategory, forKey: .perCategory)
        try c.encodeIfPresent(perSubcategory, forKey: .perSubcategory)
    }
}
