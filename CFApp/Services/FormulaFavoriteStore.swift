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
    private var cachedIds: Set<String> = []
    private var didLoadIds = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Set<String> {
        queue.sync {
            if didLoadIds {
                return cachedIds
            }
            let decoded = decodeIds(from: defaults.data(forKey: key))
            cachedIds = decoded.ids
            didLoadIds = true
            if decoded.needsMigration {
                persist(decoded.ids)
                AppLogger.info("FormulaFavoriteStore migrated legacy payload to envelope v\(currentVersion).")
            }
            return decoded.ids
        }
    }

    func save(_ ids: Set<String>) {
        queue.sync {
            cachedIds = ids
            didLoadIds = true
            persist(ids)
        }
    }

    private func persist(_ ids: Set<String>) {
        do {
            let envelope = Envelope(version: currentVersion, ids: Array(ids).sorted())
            let data = try JSONEncoder().encode(envelope)
            defaults.set(data, forKey: key)
        } catch {
            AppLogger.error("FormulaFavoriteStore persist failed: \(error.localizedDescription)")
        }
    }

    private func decodeIds(from data: Data?) -> (ids: Set<String>, needsMigration: Bool) {
        guard let data else { return ([], false) }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data) {
            return (Set(envelope.ids), false)
        }

        if let legacy = try? JSONDecoder().decode([String].self, from: data) {
            let asSet = Set(legacy)
            return (asSet, true)
        }

        AppLogger.error("FormulaFavoriteStore decode failed.")
        return ([], false)
    }
}
