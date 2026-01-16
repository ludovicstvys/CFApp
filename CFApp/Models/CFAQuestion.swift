import Foundation

/// Question CFA.
/// Supporte : 
/// - catégories (CFACategory) + sous-catégorie libre (String)
/// - 1 ou plusieurs réponses correctes (correctIndices)
///
/// Compat JSON :
/// - nouveau champ : `correctIndices: [Int]`
/// - rétrocompat : ancien champ `answerIndex: Int` → converti en `[answerIndex]`
struct CFAQuestion: Identifiable, Codable, Hashable {
    let id: String
    let level: CFALevel
    let category: CFACategory
    let subcategory: String?
    let stem: String
    let choices: [String]
    let correctIndices: [Int]
    let explanation: String
    let difficulty: Int?
    let imageName: String?
    let importedAt: Date?

    init(
        id: String,
        level: CFALevel,
        category: CFACategory,
        subcategory: String? = nil,
        stem: String,
        choices: [String],
        correctIndices: [Int],
        explanation: String,
        difficulty: Int? = nil,
        imageName: String? = nil,
        importedAt: Date? = nil
    ) {
        self.id = id
        self.level = level
        self.category = category
        self.subcategory = subcategory
        self.stem = stem
        self.choices = choices
        self.correctIndices = correctIndices.sorted()
        self.explanation = explanation
        self.difficulty = difficulty
        self.imageName = imageName
        self.importedAt = importedAt
    }

    // MARK: - Codable (rétrocompat)

    private enum CodingKeys: String, CodingKey {
        case id, level, category, subcategory, stem, choices, correctIndices, answerIndex, explanation, difficulty, imageName, importedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decode(String.self, forKey: .id)
        level = try c.decode(CFALevel.self, forKey: .level)
        category = try c.decode(CFACategory.self, forKey: .category)
        subcategory = try c.decodeIfPresent(String.self, forKey: .subcategory)
        stem = try c.decode(String.self, forKey: .stem)
        choices = try c.decode([String].self, forKey: .choices)
        explanation = try c.decode(String.self, forKey: .explanation)
        difficulty = try c.decodeIfPresent(Int.self, forKey: .difficulty)
        imageName = try c.decodeIfPresent(String.self, forKey: .imageName)
        importedAt = try c.decodeIfPresent(Date.self, forKey: .importedAt)

        if let multi = try c.decodeIfPresent([Int].self, forKey: .correctIndices), !multi.isEmpty {
            correctIndices = multi.sorted()
        } else if let single = try c.decodeIfPresent(Int.self, forKey: .answerIndex) {
            correctIndices = [single]
        } else {
            // Si absent, on force un état cohérent (évite crash)
            correctIndices = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(level, forKey: .level)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(subcategory, forKey: .subcategory)
        try c.encode(stem, forKey: .stem)
        try c.encode(choices, forKey: .choices)
        try c.encode(correctIndices, forKey: .correctIndices)
        try c.encode(explanation, forKey: .explanation)
        try c.encodeIfPresent(difficulty, forKey: .difficulty)
        try c.encodeIfPresent(imageName, forKey: .imageName)
        try c.encodeIfPresent(importedAt, forKey: .importedAt)
    }

    var isMultiAnswer: Bool { correctIndices.count > 1 }
}
