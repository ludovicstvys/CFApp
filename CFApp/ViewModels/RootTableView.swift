import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Quiz", systemImage: "questionmark.circle") }

            NavigationStack { StatsView() }
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Réglages", systemImage: "gearshape") }
        }
    }
}
