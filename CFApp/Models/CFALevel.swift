import Foundation

enum CFALevel: Int, Codable, CaseIterable, Identifiable {
    case level1 = 1
    case level2 = 2
    case level3 = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .level1: return "Niveau 1"
        case .level2: return "Niveau 2"
        case .level3: return "Niveau 3"
        }
    }
}
