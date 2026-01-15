import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {

    @AppStorage("cfaquiz.themePreference")
    private var storedValue: Int = ThemePreference.system.rawValue

    // Requis car pas de @Published -> pas de synthèse automatique
    let objectWillChange = ObservableObjectPublisher()

    var preference: ThemePreference {
        get { ThemePreference(rawValue: storedValue) ?? .system }
        set {
            storedValue = newValue.rawValue
            objectWillChange.send() // force la mise à jour des vues
        }
    }
}
