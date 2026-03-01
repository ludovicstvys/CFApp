import SwiftUI

struct CategoryPickerView: View {
    let categories: [CFACategory]
    @Binding var selected: Set<CFACategory>
    let onToggle: (CFACategory) -> Void
    let onSelectAll: () -> Void
    let onClear: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(categories, id: \.self) { cat in
                    let isSelected = selected.contains(cat)

                    Button {
                        onToggle(cat)
                        Haptics.light()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                            Label(cat.shortName, systemImage: cat.systemImage)
                                .labelStyle(.titleOnly)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .frame(minHeight: 48, alignment: .leading)
                        .background(
                            isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(cat.shortName)
                    .accessibilityValue(isSelected ? "Selectionnee" : "Non selectionnee")
                }
            }

            HStack(spacing: 10) {
                Button("Tout selectionner", action: onSelectAll)
                    .appActionButton()
                Spacer()
                Button("Tout effacer", action: onClear)
                    .appActionButton()
            }
        }
    }
}
