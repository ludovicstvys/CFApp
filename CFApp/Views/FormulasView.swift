import SwiftUI

struct FormulasView: View {
    @StateObject private var vm = FormulasViewModel()

    var body: some View {
        List {
            Section("Filtres") {
                Picker("Catégorie", selection: $vm.selectedCategory) {
                    Text("Toutes").tag(Optional<CFACategory>.none)
                    ForEach(vm.availableCategories, id: \.self) { cat in
                        Text(cat.shortName).tag(Optional(cat))
                    }
                }

                Picker("Topic", selection: $vm.selectedTopic) {
                    Text("Tous").tag(Optional<String>.none)
                    ForEach(vm.availableTopics, id: \.self) { topic in
                        Text(topic).tag(Optional(topic))
                    }
                }
                .disabled(vm.availableTopics.isEmpty)
            }

            if vm.filteredFormulas.isEmpty {
                Section {
                    Text("Aucune formule disponible.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(groupedSections, id: \.id) { section in
                    Section(section.title) {
                        ForEach(section.items) { formula in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(formula.title)
                                    .font(.headline)

                                Text(formula.formula)
                                    .font(.system(.body, design: .monospaced))
                                    .fixedSize(horizontal: false, vertical: true)

                                if let notes = formula.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let imageName = formula.imageName,
                                   let image = FormulaAssetStore.shared.loadImage(named: imageName) {
#if canImport(UIKit)
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
#elseif canImport(AppKit)
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
#endif
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .navigationTitle("Formules")
        .onChange(of: vm.selectedCategory) { _ in
            vm.onCategoryChanged()
        }
    }

    private var groupedSections: [FormulaSection] {
        let grouped = Dictionary(grouping: vm.filteredFormulas) { formula -> FormulaSectionKey in
            let topic = (formula.topic ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return FormulaSectionKey(
                category: formula.category,
                topic: topic.isEmpty ? "Autres" : topic
            )
        }
        return grouped
            .map { key, items in
                FormulaSection(
                    id: "\(key.category.rawValue)::\(key.topic)",
                    title: "\(key.category.shortName) • \(key.topic)",
                    items: items.sorted { $0.title < $1.title }
                )
            }
            .sorted { $0.title < $1.title }
    }

    private struct FormulaSectionKey: Hashable {
        let category: CFACategory
        let topic: String
    }

    private struct FormulaSection: Identifiable {
        let id: String
        let title: String
        let items: [CFAFormula]
    }
}
