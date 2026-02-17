import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var commandRouter: AppCommandRouter

    var body: some View {
        TabView(selection: $commandRouter.selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Quiz", systemImage: "questionmark.circle") }
                .tag(AppCommandRouter.Tab.quiz)

            NavigationStack { StatsView() }
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(AppCommandRouter.Tab.stats)

            NavigationStack { SettingsView() }
                .tabItem { Label("Reglages", systemImage: "gearshape") }
                .tag(AppCommandRouter.Tab.settings)
        }
    }
}
