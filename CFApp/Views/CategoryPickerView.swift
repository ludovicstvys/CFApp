import SwiftUI

struct CategoryPickerView: View {
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
                ForEach(CFACategory.allCases, id: \.self) { cat in
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
                        .padding(10)
                        .background(
                            isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                Button("Tout sélectionner", action: onSelectAll)
                Spacer()
                Button("Tout effacer", action: onClear)
            }
            .font(.footnote.weight(.semibold))
        }
    }
}
