import Foundation

protocol QuestionRepository {
    func loadAllQuestions() throws -> [CFAQuestion]
}
