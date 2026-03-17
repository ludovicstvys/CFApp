import SwiftUI

struct FormulaReferenceModuleView: View {
    @StateObject private var vm = FormulasViewModel()

    var body: some View {
        let formulas = vm.filteredFormulas

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

            if formulas.isEmpty {
                Section {
                    Text("Aucune formule disponible.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(formulas) { formula in
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
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
                            }

                            LatexTextView(content: formula.formula, isBlock: true)

                            if let notes = formula.notes, !notes.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Explication")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    LatexTextView(content: notes, isBlock: false)
                                }
                            }

                            moduleTagsView(for: formula)

                            linkedQuestionsView(for: formula)
                        }
                        .padding(.vertical, 6)
                    } header: {
                        Label(formula.category.shortName, systemImage: formula.category.systemImage)
                    }
                }
            }
        }
        .navigationTitle("Formules expliquees")
        .searchable(text: $vm.searchText, placement: .automatic, prompt: "Rechercher")
        .onAppear { vm.refresh() }
        .onChange(of: vm.selectedCategory) { _ in vm.onCategoryChanged() }
    }

    @ViewBuilder
    private func moduleTagsView(for formula: CFAFormula) -> some View {
        let modules = moduleTags(for: formula)
        if !modules.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Modules lies")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(modules, id: \.self) { module in
                            Text(module)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.1), in: Capsule())
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func linkedQuestionsView(for formula: CFAFormula) -> some View {
        let linked = vm.linkedQuestions(for: formula)
        if !linked.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Questions liees")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(linked.prefix(3)) { question in
                    Text("- \(question.stem)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if linked.count > 3 {
                    Text("+\(linked.count - 3) autres")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func moduleTags(for formula: CFAFormula) -> [String] {
        var modules: [String] = ["Module: \(formula.category.shortName)"]
        if let topic = formula.topic?.trimmingCharacters(in: .whitespacesAndNewlines), !topic.isEmpty {
            modules.append("Topic: \(topic)")
        }

        let linkedSubcategories = vm.linkedQuestions(for: formula)
            .compactMap { $0.subcategory?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let unique = Array(Set(linkedSubcategories)).sorted()
        modules.append(contentsOf: unique.map { "LOS: \($0)" })
        return modules
    }
}
