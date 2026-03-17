import SwiftUI

@main
struct CFAppApp: App {
    @StateObject private var theme = ThemeManager()
    @StateObject private var commandRouter = AppCommandRouter()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(theme)
                .environmentObject(commandRouter)
                .preferredColorScheme(theme.preference.colorScheme)
        }
#if os(macOS)
        .commands {
            CommandMenu("Navigation") {
                Button("Quiz") {
                    commandRouter.select(.quiz)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Revision Formules") {
                    commandRouter.select(.formulaRevision)
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("Formules Expliquees") {
                    commandRouter.select(.formulaReference)
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button("Stats") {
                    commandRouter.select(.stats)
                }
                .keyboardShortcut("4", modifiers: [.command])

                Button("Settings") {
                    commandRouter.select(.settings)
                }
                .keyboardShortcut("5", modifiers: [.command])
            }

            CommandMenu("Data") {
                Button("Open ZIP Import") {
                    commandRouter.requestImport()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }
#endif
    }
}
