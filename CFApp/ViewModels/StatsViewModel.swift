import Foundation
import Combine

@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var attempts: [QuizAttempt] = []

    func refresh() {
        attempts = StatsStore.shared.loadAttempts()
    }

    func clearAll() {
        StatsStore.shared.clear()
        refresh()
    }

    var totalAttempts: Int { attempts.count }

    var overallAccuracy: Double {
        let total = attempts.reduce(0) { $0 + $1.total }
        let score = attempts.reduce(0) { $0 + $1.score }
        guard total > 0 else { return 0 }
        return Double(score) / Double(total)
    }

    var bestScorePct: Double {
        guard let best = attempts.map({ Double($0.score) / Double(max(1, $0.total)) }).max() else { return 0 }
        return best
    }
}
