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

    init(resourceName: String = "ImportedFormulas") {
        self.resourceName = resourceName
    }

    func loadAllFormulas() throws -> [CFAFormula] {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json") else {
            throw StoreError.missingResource("\(resourceName).json")
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([CFAFormula].self, from: data)
        } catch {
            throw StoreError.decodingFailed(error)
        }
    }
}
