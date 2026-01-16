import Foundation

/// Repository distant (optionnel) avec cache local.
/// Exemple : GET /questions?level=1&category=Ethics
struct RemoteQuestionRepository: QuestionRepositoryAsync {
    let api: RemoteAPI
    let cache: QuestionDiskStore

    init(api: RemoteAPI, cache: QuestionDiskStore = .shared) {
        self.api = api
        self.cache = cache
    }

    func loadAllQuestions() async throws -> [CFAQuestion] {
        do {
            let data = try await api.get(path: "questions")
            let decoder = JSONDecoder()
            let questions = try decoder.decode([CFAQuestion].self, from: data)
            cache.save(questions)
            return questions
        } catch {
            let cached = cache.load()
            if !cached.isEmpty {
                return cached
            }
            throw error
        }
    }
}
