import SwiftUI

enum AppButtonMetrics {
    static let cornerRadius: CGFloat = 14
    static let minHeight: CGFloat = 50
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 13
}

private struct AppActionButtonModifier: ViewModifier {
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let base = content
            .font(.subheadline.weight(.semibold))
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: AppButtonMetrics.cornerRadius))

        if prominent {
            base.buttonStyle(.borderedProminent)
        } else {
            base.buttonStyle(.bordered)
        }
    }
}

extension View {
    func appActionButton(prominent: Bool = false) -> some View {
        modifier(AppActionButtonModifier(prominent: prominent))
    }
}
