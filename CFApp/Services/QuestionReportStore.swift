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

    private struct Envelope: Codable {
        let version: Int
        let reports: [QuestionReport]
    }

    private let key = "cfaquiz.questionReports.v1"
    private let currentVersion = 2
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "cfaquiz.questionReportStore")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadReports() -> [QuestionReport] {
        queue.sync {
            decodeReports(from: defaults.data(forKey: key)) ?? []
        }
    }

    func saveReport(_ report: QuestionReport) {
        queue.sync {
            var all = decodeReports(from: defaults.data(forKey: key)) ?? []
            all.insert(report, at: 0)
            persist(all)
        }
    }

    func saveReports(_ reports: [QuestionReport]) {
        queue.sync {
            persist(reports)
        }
    }

    func clear() {
        queue.sync {
            defaults.removeObject(forKey: key)
        }
    }

    private func decodeReports(from data: Data?) -> [QuestionReport]? {
        guard let data else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(Envelope.self, from: data)
            return envelope.reports
        } catch {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let legacy = try decoder.decode([QuestionReport].self, from: data)
                persist(legacy)
                AppLogger.info("QuestionReportStore migrated legacy payload to envelope v\(currentVersion).")
                return legacy
            } catch {
                AppLogger.error("QuestionReportStore decode failed: \(error.localizedDescription)")
                return nil
            }
        }
    }

    private func persist(_ reports: [QuestionReport]) {
        do {
            let envelope = Envelope(version: currentVersion, reports: reports)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(envelope)
            defaults.set(data, forKey: key)
        } catch {
            AppLogger.error("QuestionReportStore persist failed: \(error.localizedDescription)")
        }
    }
}
