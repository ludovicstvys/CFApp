import SwiftUI

struct ChoiceRowView: View {
    let text: String
    let isSelected: Bool
    /// nil => pas de feedback, true/false => feedback (correct / incorrect selected)
    let isCorrect: Bool?
    let isMultiSelect: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .padding(.top, 2)

                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(minHeight: 56, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityValue(accessibilityStatus)
        .accessibilityHint(isMultiSelect ? "Double tapez pour cocher ou decocher cette reponse" : "Double tapez pour choisir cette reponse")
    }

    private var iconName: String {
        if let isCorrect {
            if isCorrect { return "checkmark.circle.fill" }
            return isSelected ? "xmark.circle.fill" : "circle"
        }

        if isMultiSelect {
            return isSelected ? "checkmark.square.fill" : "square"
        } else {
            return isSelected ? "circle.inset.filled" : "circle"
        }
    }

    private var iconColor: Color {
        if let isCorrect {
            return isCorrect ? .green : (isSelected ? .red : .secondary)
        }
        return isSelected ? .accentColor : .secondary
    }

    private var background: AnyShapeStyle {
        if let isCorrect {
            if isCorrect {
                return AnyShapeStyle(Color.green.opacity(0.15))
            } else if isSelected {
                return AnyShapeStyle(Color.red.opacity(0.12))
            }
        }
        return AnyShapeStyle(Color.secondary.opacity(0.08))
    }

    private var borderColor: Color {
        if let isCorrect {
            if isCorrect { return .green.opacity(0.55) }
            if isSelected { return .red.opacity(0.45) }
            return .secondary.opacity(0.18)
        }
        return isSelected ? Color.accentColor.opacity(0.45) : .secondary.opacity(0.18)
    }

    private var accessibilityStatus: String {
        if let isCorrect {
            if isCorrect { return "Bonne reponse" }
            if isSelected { return "Mauvaise reponse selectionnee" }
            return "Non selectionnee"
        }
        return isSelected ? "Selectionnee" : "Non selectionnee"
    }
}
