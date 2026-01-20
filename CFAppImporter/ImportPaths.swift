import Foundation

enum ImportPaths {
    static var repoRoot: URL {
        if let env = ProcessInfo.processInfo.environment["CFAPP_REPO_ROOT"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidate = home.appendingPathComponent("Desktop/Cours/Projet/CFApp", isDirectory: true)
        if isValidRepoRoot(candidate) {
            return candidate
        }

        let fallback = home.appendingPathComponent("CFApp", isDirectory: true)
        if isValidRepoRoot(fallback) {
            return fallback
        }

        return candidate
    }

    static var importInbox: URL {
        repoRoot.appendingPathComponent("ImportInbox", isDirectory: true)
    }

    static var appDataDir: URL {
        repoRoot.appendingPathComponent("CFApp", isDirectory: true)
    }

    static var questionsFile: URL {
        appDataDir.appendingPathComponent("ImportedQuestions.json")
    }

    static var formulasFile: URL {
        appDataDir.appendingPathComponent("ImportedFormulas.json")
    }

    static var assetsDir: URL {
        appDataDir.appendingPathComponent("ImportedAssets", isDirectory: true)
    }

    static var formulaAssetsDir: URL {
        appDataDir.appendingPathComponent("ImportedFormulaAssets", isDirectory: true)
    }

    static func ensureDirectories() {
        let fm = FileManager.default
        let dirs = [importInbox, appDataDir, assetsDir, formulaAssetsDir]
        for dir in dirs {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    static func isValidRepoRoot(_ url: URL) -> Bool {
        let marker = url.appendingPathComponent("CFApp.xcodeproj").path
        return FileManager.default.fileExists(atPath: marker)
    }
}
