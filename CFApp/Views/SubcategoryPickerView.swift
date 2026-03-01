import SwiftUI

struct SubcategoryPickerView: View {
    let available: [String]
    @Binding var selected: Set<String>
    let onToggle: (String) -> Void
    let onSelectAll: () -> Void
    let onClear: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if available.isEmpty {
                Text("Aucune sous-categorie detectee pour ces filtres.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(available, id: \.self) { sub in
                        let isSelected = selected.contains(sub)
                        Button {
                            onToggle(sub)
                            Haptics.light()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                                Text(sub)
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
                    }
                }

                HStack(spacing: 10) {
                    Button("Tout selectionner", action: onSelectAll)
                        .appActionButton()
                    Spacer()
                    Button("Tout effacer (pas de filtre)", action: onClear)
                        .appActionButton()
                }

                Text("Astuce : si rien n'est selectionne, on ne filtre pas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
