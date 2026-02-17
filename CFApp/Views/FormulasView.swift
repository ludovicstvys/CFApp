import SwiftUI

struct FormulasView: View {
    @StateObject private var vm = FormulasViewModel()

    var body: some View {
        List {
            Section("Filtres") {
                Picker("Categorie", selection: $vm.selectedCategory) {
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

                Toggle("Favoris uniquement", isOn: $vm.showFavoritesOnly)
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
                                HStack(spacing: 10) {
                                    Text(formula.title)
                                        .font(.headline)
                                    Spacer()
                                    Button {
                                        vm.toggleFavorite(formula)
                                    } label: {
                                        Image(systemName: vm.isFavorite(formula) ? "star.fill" : "star")
                                            .foregroundStyle(vm.isFavorite(formula) ? .yellow : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(vm.isFavorite(formula) ? "Retirer des favoris" : "Ajouter aux favoris")
                                }

                                Text(formula.formula)
                                    .font(.system(.body, design: .monospaced))
                                    .fixedSize(horizontal: false, vertical: true)

                                if let notes = formula.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let imageName = formula.imageName {
#if canImport(UIKit) || canImport(AppKit)
                                    AsyncPlatformImageView(
                                        imageName: imageName,
                                        loader: { await FormulaAssetStore.shared.loadImageAsync(named: $0) }
                                    )
#endif
                                }

                                let linked = vm.linkedQuestions(for: formula)
                                if !linked.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Questions liees")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        ForEach(linked.prefix(3)) { question in
                                            Text("• \(question.stem)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        if linked.count > 3 {
                                            Text("... +\(linked.count - 3)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .navigationTitle("Formules")
        .searchable(text: $vm.searchText, placement: .automatic, prompt: "Rechercher une formule")
        .onChange(of: vm.selectedCategory) { _ in
            vm.onCategoryChanged()
        }
        .onAppear {
            vm.refresh()
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
