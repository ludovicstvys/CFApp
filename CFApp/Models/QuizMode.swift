import Foundation

enum QuizMode: String, Codable, CaseIterable, Identifiable {
    case revision
    case test
    case mock
    case random
    case spaced
    case formulas

    var id: String { rawValue }

    var title: String {
        switch self {
        case .revision: return "Revision"
        case .test: return "Test"
        case .mock: return "Mock Exam"
        case .random: return "Aleatoire"
        case .spaced: return "SRS"
        case .formulas: return "Formules"
        }
    }

    var description: String {
        switch self {
        case .revision:
            return "Feedback immediat + explications."
        case .test:
            return "Score a la fin (comme un mock)."
        case .mock:
            return "Examen blanc chronometre avec reprise possible."
        case .random:
            return "Melange toutes les categories du niveau."
        case .spaced:
            return "Priorise les questions oubliees."
        case .formulas:
            return "Quiz de formules avec auto-verification."
        }
    }
}
