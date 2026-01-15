import SwiftUI

@main
struct CFAppApp: App {
    @StateObject private var theme = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(theme)
                .preferredColorScheme(theme.preference.colorScheme)
        }
    }
}
