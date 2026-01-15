import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        Form {
            Section("Apparence") {
                Picker("Thème", selection: Binding(
                    get: { theme.preference },
                    set: { theme.preference = $0 }
                )) {
                    ForEach(ThemePreference.allCases) { p in
                        Text(p.title).tag(p)
                    }
                }
            }

            Section("Données") {
                Text("Les questions du niveau 1 sont chargées depuis un JSON embarqué (offline).")
                    .foregroundStyle(.secondary)

                NavigationLink {
                    CSVImportView()
                } label: {
                    Label("Importer des questions (CSV)", systemImage: "square.and.arrow.down")
                }
            }

            Section("À venir (idées)") {
                Text("• Gamification (streak, badges)\n• Synchronisation multi-appareils\n• Génération de tests par LOS\n• Import/export CSV/JSON\n• Mode “mock exam” multi-sessions")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Réglages")
    }
}
