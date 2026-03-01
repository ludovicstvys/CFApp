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
    private static let cacheQueue = DispatchQueue(
        label: "cfaquiz.localQuestionStore.cache",
        attributes: .concurrent
    )
    private static var cachedByResource: [String: [CFAQuestion]] = [:]

    init(resourceName: String = "SampleQuestions_L1") {
        self.resourceName = resourceName
    }

    func loadAllQuestions() throws -> [CFAQuestion] {
        if let cached = Self.cachedQuestions(for: resourceName) {
            return cached
        }

        let primaryURL = Bundle.main.url(forResource: resourceName, withExtension: "json")
        let fallbackURL = resourceName == "SampleQuestions_L1"
            ? nil
            : Bundle.main.url(forResource: "SampleQuestions_L1", withExtension: "json")
        guard let url = primaryURL ?? fallbackURL else {
            throw StoreError.missingResource("\(resourceName).json")
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            // Stable: on laisse les dates à la couche stats, pas dans les questions
            let decoded = try decoder.decode([CFAQuestion].self, from: data)
            Self.storeCache(decoded, for: resourceName)
            return decoded
        } catch {
            throw StoreError.decodingFailed(error)
        }
    }

    private static func cachedQuestions(for resourceName: String) -> [CFAQuestion]? {
        cacheQueue.sync { cachedByResource[resourceName] }
    }

    private static func storeCache(_ questions: [CFAQuestion], for resourceName: String) {
        cacheQueue.async(flags: .barrier) {
            cachedByResource[resourceName] = questions
        }
    }
}
