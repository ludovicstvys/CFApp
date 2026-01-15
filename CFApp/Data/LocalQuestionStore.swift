import Foundation

/// Charge les questions depuis un JSON du bundle.
/// Offline-first : ne dépend d'aucun backend.
struct LocalQuestionStore: QuestionRepository {
    enum StoreError: Error, LocalizedError {
        case missingResource(String)
        case decodingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .missingResource(let name):
                return "Fichier introuvable dans le bundle: \(name)"
            case .decodingFailed(let err):
                return "Décodage JSON impossible: \(err.localizedDescription)"
            }
        }
    }

    let resourceName: String

    init(resourceName: String = "SampleQuestions_L1") {
        self.resourceName = resourceName
    }

    func loadAllQuestions() throws -> [CFAQuestion] {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            throw StoreError.missingResource("\(resourceName).json")
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            // Stable: on laisse les dates à la couche stats, pas dans les questions
            return try decoder.decode([CFAQuestion].self, from: data)
        } catch {
            throw StoreError.decodingFailed(error)
        }
    }
}
