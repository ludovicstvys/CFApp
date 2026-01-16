import Foundation

protocol QuestionRepository {
    func loadAllQuestions() throws -> [CFAQuestion]
}

protocol QuestionRepositoryAsync {
    func loadAllQuestions() async throws -> [CFAQuestion]
}
