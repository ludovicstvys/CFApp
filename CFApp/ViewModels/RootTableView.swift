import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var commandRouter: AppCommandRouter

    var body: some View {
        TabView(selection: $commandRouter.selectedTab) {
            LazyTabContent {
                NavigationStack { HomeView() }
            }
                .tabItem { Label("Quiz", systemImage: "questionmark.circle") }
                .tag(AppCommandRouter.Tab.quiz)

            LazyTabContent {
                NavigationStack { StatsView() }
            }
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(AppCommandRouter.Tab.stats)

            LazyTabContent {
                NavigationStack { SettingsView() }
            }
                .tabItem { Label("Reglages", systemImage: "gearshape") }
                .tag(AppCommandRouter.Tab.settings)
        }
    }
}

private struct LazyTabContent<Content: View>: View {
    let content: () -> Content
    @State private var didLoad = false

    var body: some View {
        Group {
            if didLoad {
                content()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { didLoad = true }
            }
        }
    }
}
