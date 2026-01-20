import Foundation

final class FormulaDiskStore {
    static let shared = FormulaDiskStore()
    private init() {}

    private var fileURL: URL {
        ImportPaths.ensureDirectories()
        return ImportPaths.formulasFile
    }

    func load() -> [CFAFormula] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([CFAFormula].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ formulas: [CFAFormula]) {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(formulas)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // ignore
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
