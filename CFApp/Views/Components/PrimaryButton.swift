import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppButtonMetrics.minHeight)
            .padding(.horizontal, AppButtonMetrics.horizontalPadding)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .appActionButton(prominent: true)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
        .accessibilityHint(isEnabled ? "Active l'action principale" : "Action desactivee")
    }
}
