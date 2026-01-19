import Foundation

struct QuestionReport: Identifiable, Codable {
    enum IssueType: String, Codable, CaseIterable, Identifiable {
        case typo
        case ambiguity
        case other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .typo: return "Typo"
            case .ambiguity: return "Ambiguite"
            case .other: return "Autre"
            }
        }
    }

    let id: String
    let createdAt: Date
    let questionId: String
    let level: CFALevel
    let category: CFACategory
    let subcategory: String?
    let stem: String
    let choices: [String]
    let explanation: String
    let imageName: String?
    let issueType: IssueType
    let note: String?
    let importedAt: Date?

    init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        question: CFAQuestion,
        issueType: IssueType,
        note: String?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.questionId = question.id
        self.level = question.level
        self.category = question.category
        self.subcategory = question.subcategory
        self.stem = question.stem
        self.choices = question.choices
        self.explanation = question.explanation
        self.imageName = question.imageName
        self.issueType = issueType
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.note = trimmed.isEmpty ? nil : trimmed
        self.importedAt = question.importedAt
    }
}

final class QuestionReportStore {
    static let shared = QuestionReportStore()

    private let key = "cfaquiz.questionReports.v1"
    private let defaults = UserDefaults.standard

    private init() {}

    func loadReports() -> [QuestionReport] {
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([QuestionReport].self, from: data)
        } catch {
            return []
        }
    }

    func saveReport(_ report: QuestionReport) {
        var all = loadReports()
        all.insert(report, at: 0)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(all)
            defaults.set(data, forKey: key)
        } catch {
            // ignore
        }
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
