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
                Text("Aucune sous-catégorie détectée pour ces filtres.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(available, id: \.self) { sub in
                        Button {
                            onToggle(sub)
                            Haptics.light()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selected.contains(sub) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(sub) ? Color.accentColor : .secondary)

                                Text(sub)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)

                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .background(selected.contains(sub) ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 10) {
                    Button("Tout sélectionner", action: onSelectAll)
                    Spacer()
                    Button("Tout effacer (pas de filtre)", action: onClear)
                }
                .font(.footnote.weight(.semibold))

                Text("Astuce : si rien n’est sélectionné, on ne filtre pas (toutes les sous-catégories).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
