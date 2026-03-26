import SwiftUI

struct FormulaRevisionModuleView: View {
    @StateObject private var vm = FormulasViewModel()
    @State private var currentIndex = 0
    @State private var isRevealed = false

    private var deck: [CFAFormula] {
        vm.filteredFormulas
    }

    private var current: CFAFormula? {
        guard !deck.isEmpty, currentIndex < deck.count else { return nil }
        return deck[currentIndex]
    }

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

            if deck.isEmpty {
                Section {
                    Text("Aucune formule pour ces filtres.")
                        .foregroundStyle(.secondary)
                }
            } else if let current {
                Section("Progression") {
                    Text("\(currentIndex + 1)/\(deck.count)")
                        .font(.headline.monospacedDigit())
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(current.category.shortName, systemImage: current.category.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if let topic = current.topic, !topic.isEmpty {
                            Text(topic)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text(current.title)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        if isRevealed {
                            LatexTextView(content: current.formula, isBlock: true)

                            if let notes = current.notes, !notes.isEmpty {
                                LatexTextView(content: notes, isBlock: false)
                            }
                        } else {
                            Text("Essaie de retrouver la formule, puis clique sur Afficher.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    if !isRevealed {
                        Button {
                            isRevealed = true
                        } label: {
                            Label("Afficher la formule", systemImage: "eye")
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: AppButtonMetrics.minHeight)
                        }
                        .appActionButton(prominent: true)
                    } else {
                        HStack(spacing: 10) {
                            Button {
                                nextCard()
                            } label: {
                                Label("Je savais", systemImage: "checkmark")
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: AppButtonMetrics.minHeight)
                            }
                            .appActionButton(prominent: true)

                            Button {
                                vm.toggleFavorite(current)
                                nextCard()
                            } label: {
                                Label("A revoir", systemImage: "arrow.uturn.left")
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: AppButtonMetrics.minHeight)
                            }
                            .appActionButton()
                        }
                    }
                }
            }
        }
        .navigationTitle("Revision formules")
        .searchable(text: $vm.searchText, placement: .automatic, prompt: "Rechercher")
        .onAppear {
            vm.refresh()
            clampIndexIfNeeded()
        }
        .onChange(of: vm.selectedCategory) { _ in
            vm.onCategoryChanged()
            clampIndexIfNeeded(resetReveal: true)
        }
        .onChange(of: vm.selectedTopic) { _ in
            clampIndexIfNeeded(resetReveal: true)
        }
        .onChange(of: vm.showFavoritesOnly) { _ in
            clampIndexIfNeeded(resetReveal: true)
        }
        .onChange(of: vm.searchText) { _ in
            clampIndexIfNeeded(resetReveal: true)
        }
    }

    private func nextCard() {
        guard !deck.isEmpty else { return }
        currentIndex = (currentIndex + 1) % deck.count
        isRevealed = false
    }

    private func clampIndexIfNeeded(resetReveal: Bool = false) {
        if deck.isEmpty {
            currentIndex = 0
        } else if currentIndex >= deck.count {
            currentIndex = 0
        }
        if resetReveal {
            isRevealed = false
        }
    }
}
