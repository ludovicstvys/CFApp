import Foundation

struct CFAFormula: Identifiable, Codable, Hashable {
    let id: String
    let category: CFACategory
    let topic: String?
    let title: String
    let formula: String
    let notes: String?
    let imageName: String?
    let questionIds: [String]?
    let importedAt: Date?

    init(
        id: String = UUID().uuidString,
        category: CFACategory,
        topic: String? = nil,
        title: String,
        formula: String,
        notes: String? = nil,
        imageName: String? = nil,
        questionIds: [String]? = nil,
        importedAt: Date? = nil
    ) {
        self.id = id
        self.category = category
        self.topic = topic
        self.title = title
        self.formula = formula
        self.notes = notes
        self.imageName = imageName
        self.questionIds = questionIds
        self.importedAt = importedAt
    }
}
