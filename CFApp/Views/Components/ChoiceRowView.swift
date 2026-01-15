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
            .padding(12)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
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
}
