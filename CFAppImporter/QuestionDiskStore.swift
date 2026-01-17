import Foundation

final class QuestionDiskStore {
    static let shared = QuestionDiskStore()
    private init() {}

    private var fileURL: URL {
        let fm = FileManager.default
        let root = repoRootURL() ?? URL(fileURLWithPath: fm.currentDirectoryPath)
        let appDir = root.appendingPathComponent("CFApp", isDirectory: true)
        if !fm.fileExists(atPath: appDir.path) {
            try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir.appendingPathComponent("ImportedQuestions.json")
    }

    private func repoRootURL() -> URL? {
        let env = ProcessInfo.processInfo.environment["CFAPP_REPO_ROOT"]
        if let env, !env.isEmpty {
            return URL(fileURLWithPath: env)
        }

        let fm = FileManager.default
        var current = URL(fileURLWithPath: fm.currentDirectoryPath)
        while current.path != "/" {
            let marker = current.appendingPathComponent("CFApp.xcodeproj").path
            if fm.fileExists(atPath: marker) {
                return current
            }
            current.deleteLastPathComponent()
        }
        return nil
    }

    func load() -> [CFAQuestion] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([CFAQuestion].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ questions: [CFAQuestion]) {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(questions)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // ignore
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
