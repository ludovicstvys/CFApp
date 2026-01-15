import Foundation

/// Repository distant (optionnel).
/// Exemple : GET /questions?level=1&category=Ethics
struct RemoteQuestionRepository: QuestionRepository {
    let api: RemoteAPI

    func loadAllQuestions() throws -> [CFAQuestion] {
        // Ce repository est async en réalité; on le laisse en stub pour garder le protocole simple.
        // Approche recommandée : créer un QuestionRepositoryAsync ou utiliser Combine/async.
        return []
    }
}
