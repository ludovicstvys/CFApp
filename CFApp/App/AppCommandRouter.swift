import Foundation
import Combine

@MainActor
final class AppCommandRouter: ObservableObject {
    struct TargetedQuizRequest: Identifiable {
        let id: UUID
        let categories: [CFACategory]
        let level: CFALevel
        let questionCount: Int

        init(
            id: UUID = UUID(),
            categories: [CFACategory],
            level: CFALevel = .level1,
            questionCount: Int = 20
        ) {
            self.id = id
            self.categories = categories
            self.level = level
            self.questionCount = questionCount
        }
    }

    enum Tab: Hashable {
        case quiz
        case stats
        case settings
    }

    @Published var selectedTab: Tab = .quiz
    @Published var openImportRequestId: UUID = UUID()
    @Published var targetedQuizRequest: TargetedQuizRequest? = nil

    func select(_ tab: Tab) {
        selectedTab = tab
    }

    func requestImport() {
        selectedTab = .settings
        openImportRequestId = UUID()
    }

    func requestTargetedQuiz(
        categories: [CFACategory],
        level: CFALevel = .level1,
        questionCount: Int = 20
    ) {
        selectedTab = .quiz
        targetedQuizRequest = TargetedQuizRequest(
            categories: categories,
            level: level,
            questionCount: questionCount
        )
    }

    func consumeTargetedQuizRequest() {
        targetedQuizRequest = nil
    }
}
