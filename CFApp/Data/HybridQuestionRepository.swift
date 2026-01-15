import Foundation

/// Repository "hybride" : bundle + questions importées (disque).
/// Si un ID est dupliqué, la version importée écrase celle du bundle.
struct HybridQuestionRepository: QuestionRepository {
    let bundleStore: LocalQuestionStore
    let diskStore: QuestionDiskStore

    init(bundleResourceName: String = "SampleQuestions_L1", diskStore: QuestionDiskStore = .shared) {
        self.bundleStore = LocalQuestionStore(resourceName: bundleResourceName)
        self.diskStore = diskStore
    }

    func loadAllQuestions() throws -> [CFAQuestion] {
        let bundle = try bundleStore.loadAllQuestions()
        let imported = diskStore.load()

        var dict = Dictionary(uniqueKeysWithValues: bundle.map { ($0.id, $0) })
        for q in imported { dict[q.id] = q }

        return Array(dict.values)
    }
}
