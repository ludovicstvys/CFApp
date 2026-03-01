import Foundation
import Combine

@MainActor
final class AppCommandRouter: ObservableObject {
    enum Tab: Hashable {
        case quiz
        case stats
        case settings
    }

    @Published var selectedTab: Tab = .quiz
    @Published var openImportRequestId: UUID = UUID()

    func select(_ tab: Tab) {
        selectedTab = tab
    }

    func requestImport() {
        selectedTab = .settings
        openImportRequestId = UUID()
    }
}
