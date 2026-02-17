import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {

    @AppStorage("cfaquiz.themePreference")
    private var storedValue: Int = ThemePreference.system.rawValue

    // Custom publisher because we do not use @Published on computed properties.
    let objectWillChange = ObservableObjectPublisher()

    var preference: ThemePreference {
        get { ThemePreference(rawValue: storedValue) ?? .system }
        set {
            storedValue = newValue.rawValue
            objectWillChange.send()
        }
    }
}
