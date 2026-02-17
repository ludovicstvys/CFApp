import Foundation

final class FormulaFavoriteStore {
    static let shared = FormulaFavoriteStore()

    private struct Envelope: Codable {
        let version: Int
        let ids: [String]
    }

    private let key = "cfaquiz.formulaFavorites.v1"
    private let currentVersion = 2
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "cfaquiz.formulaFavoriteStore")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Set<String> {
        queue.sync {
            decodeIds(from: defaults.data(forKey: key))
        }
    }

    func save(_ ids: Set<String>) {
        queue.sync {
            do {
                let envelope = Envelope(version: currentVersion, ids: Array(ids).sorted())
                let data = try JSONEncoder().encode(envelope)
                defaults.set(data, forKey: key)
            } catch {
                AppLogger.error("FormulaFavoriteStore persist failed: \(error.localizedDescription)")
            }
        }
    }

    private func decodeIds(from data: Data?) -> Set<String> {
        guard let data else { return [] }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data) {
            return Set(envelope.ids)
        }

        if let legacy = try? JSONDecoder().decode([String].self, from: data) {
            let asSet = Set(legacy)
            save(asSet)
            AppLogger.info("FormulaFavoriteStore migrated legacy payload to envelope v\(currentVersion).")
            return asSet
        }

        AppLogger.error("FormulaFavoriteStore decode failed.")
        return []
    }
}
