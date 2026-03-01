import Foundation

struct LocalFormulaStore {
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
        label: "cfaquiz.localFormulaStore.cache",
        attributes: .concurrent
    )
    private static var cachedByResource: [String: [CFAFormula]] = [:]

    init(resourceName: String = "ImportedFormulas") {
        self.resourceName = resourceName
    }

    func loadAllFormulas() throws -> [CFAFormula] {
        if let cached = Self.cachedFormulas(for: resourceName) {
            return cached
        }

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            throw StoreError.missingResource("\(resourceName).json")
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([CFAFormula].self, from: data)
            Self.storeCache(decoded, for: resourceName)
            return decoded
        } catch {
            throw StoreError.decodingFailed(error)
        }
    }

    private static func cachedFormulas(for resourceName: String) -> [CFAFormula]? {
        cacheQueue.sync { cachedByResource[resourceName] }
    }

    private static func storeCache(_ formulas: [CFAFormula], for resourceName: String) {
        cacheQueue.async(flags: .barrier) {
            cachedByResource[resourceName] = formulas
        }
    }
}
