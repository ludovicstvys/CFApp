import Foundation

enum QuizMode: String, Codable, CaseIterable, Identifiable {
    case revision
    case test
    case random
    case spaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .revision: return "Révision"
        case .test: return "Test"
        case .random: return "Aléatoire"
        case .spaced: return "SRS"
        }
    }

    var description: String {
        switch self {
        case .revision:
            return "Feedback immédiat + explications."
        case .test:
            return "Score à la fin (comme un mock)."
        case .random:
            return "Mélange toutes les catégories du niveau."
        case .spaced:
            return "Priorise les questions oubliées."
        }
    }
}
