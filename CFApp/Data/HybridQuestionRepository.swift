import Foundation

/// Repository "hybride" : bundle + questions importées (disque).
/// Si un ID est dupliqué, la version importée écrase celle du bundle.
struct HybridQuestionRepository: QuestionRepository {
    let bundleStore: LocalQuestionStore
    let diskStore: QuestionDiskStore

    init(bundleResourceName: String = "ImportedQuestions", diskStore: QuestionDiskStore = .shared) {
        self.bundleStore = LocalQuestionStore(resourceName: bundleResourceName)
        self.diskStore = diskStore
    }

    func loadAllQuestions() throws -> [CFAQuestion] {
        let bundle = try bundleStore.loadAllQuestions()
        let imported = diskStore.load()

        var dict = Dictionary(uniqueKeysWithValues: bundle.map { ($0.id, $0) })
        for q in imported {
            if let existing = dict[q.id] {
                let existingDate = existing.importedAt ?? .distantPast
                let newDate = q.importedAt ?? .distantPast
                if newDate >= existingDate {
                    dict[q.id] = q
                }
            } else {
                dict[q.id] = q
            }
        }

        return Array(dict.values)
    }
}
