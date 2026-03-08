import SwiftUI

struct ToastBannerView: View {
    enum Tone {
        case info
        case success
        case error
    }

    let message: String
    let tone: Tone

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        .padding(.horizontal)
    }

    private var iconName: String {
        switch tone {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch tone {
        case .info: return .accentColor
        case .success: return .green
        case .error: return .orange
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .info: return Color.secondary.opacity(0.12)
        case .success: return Color.green.opacity(0.14)
        case .error: return Color.orange.opacity(0.16)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .info: return .secondary.opacity(0.2)
        case .success: return .green.opacity(0.45)
        case .error: return .orange.opacity(0.45)
        }
    }
}
