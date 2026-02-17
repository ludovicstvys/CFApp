import SwiftUI

struct ReviewView: View {
    let records: [QuizViewModel.AnswerRecord]

    @AppStorage("cfaquiz.review.showIncorrectOnly")
    private var showIncorrectOnly = false
    @AppStorage("cfaquiz.review.selectedCategory")
    private var persistedCategoryRaw = ""
    @AppStorage("cfaquiz.review.selectedSubcategory")
    private var persistedSubcategory = ""
    @AppStorage("cfaquiz.review.searchText")
    private var searchText = ""

    var body: some View {
        List {
            Section("Filtres") {
                Toggle("Afficher uniquement les erreurs", isOn: $showIncorrectOnly)

                Picker("Categorie", selection: selectedCategoryBinding) {
                    Text("Toutes").tag(Optional<CFACategory>.none)
                    ForEach(availableCategories, id: \.self) { cat in
                        Text(cat.shortName).tag(Optional(cat))
                    }
                }

                Picker("Sous-categorie", selection: selectedSubcategoryBinding) {
                    Text("Toutes").tag(Optional<String>.none)
                    ForEach(availableSubcategories, id: \.self) { sub in
                        Text(sub).tag(Optional(sub))
                    }
                }
                .disabled(availableSubcategories.isEmpty)
            }

            ForEach(filteredRecords) { r in
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(r.stem)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)

                        if let sub = r.subcategory, !sub.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(sub)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(r.choices.enumerated()), id: \.offset) { idx, choice in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: marker(for: r, idx: idx))
                                        .foregroundStyle(color(for: r, idx: idx))
                                        .padding(.top, 2)
                                    Text(choice)
                                }
                            }
                        }

                        Text(r.explanation)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Label(r.category.shortName, systemImage: r.category.systemImage)
                }
            }
        }
        .navigationTitle("Revue")
#if os(iOS) || os(tvOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .searchable(text: $searchText, placement: .automatic, prompt: "Rechercher une question")
        .onChange(of: persistedCategoryRaw) { _ in
            guard let selectedSub = selectedSubcategoryBinding.wrappedValue else { return }
            if !availableSubcategories.contains(selectedSub) {
                selectedSubcategoryBinding.wrappedValue = nil
            }
        }
    }

    private func marker(for r: QuizViewModel.AnswerRecord, idx: Int) -> String {
        if r.correctIndices.contains(idx) { return "checkmark.circle.fill" }
        if r.selectedIndices.contains(idx) { return "xmark.circle.fill" }
        return "circle"
    }

    private func color(for r: QuizViewModel.AnswerRecord, idx: Int) -> Color {
        if r.correctIndices.contains(idx) { return .green }
        if r.selectedIndices.contains(idx) { return .red }
        return .secondary
    }

    private var selectedCategoryBinding: Binding<CFACategory?> {
        Binding(
            get: {
                let raw = persistedCategoryRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                return raw.isEmpty ? nil : CFACategory(raw)
            },
            set: { newValue in
                persistedCategoryRaw = newValue?.rawValue ?? ""
            }
        )
    }

    private var selectedSubcategoryBinding: Binding<String?> {
        Binding(
            get: {
                let raw = persistedSubcategory.trimmingCharacters(in: .whitespacesAndNewlines)
                return raw.isEmpty ? nil : raw
            },
            set: { newValue in
                persistedSubcategory = newValue ?? ""
            }
        )
    }

    private var filteredRecords: [QuizViewModel.AnswerRecord] {
        let selectedCategory = selectedCategoryBinding.wrappedValue
        let selectedSubcategory = selectedSubcategoryBinding.wrappedValue
        let normalizedNeedle = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()

        return records.filter { r in
            if showIncorrectOnly, r.isCorrect { return false }
            if let selectedCategory, r.category != selectedCategory { return false }
            if let selectedSubcategory {
                let sub = (r.subcategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if sub != selectedSubcategory { return false }
            }
            if !normalizedNeedle.isEmpty {
                let haystack = [
                    r.stem,
                    r.explanation,
                    r.subcategory ?? "",
                    r.category.rawValue,
                    r.category.shortName
                ]
                    .joined(separator: " ")
                    .folding(options: .diacriticInsensitive, locale: .current)
                    .lowercased()
                if !haystack.contains(normalizedNeedle) {
                    return false
                }
            }
            return true
        }
    }

    private var availableCategories: [CFACategory] {
        Array(Set(records.map { $0.category })).sorted { $0.rawValue < $1.rawValue }
    }

    private var availableSubcategories: [String] {
        let selectedCategory = selectedCategoryBinding.wrappedValue
        let filtered = records.filter { r in
            if let selectedCategory, r.category != selectedCategory { return false }
            return true
        }
        let subs = filtered.compactMap { $0.subcategory?.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Array(Set(subs)).filter { !$0.isEmpty }.sorted()
    }
}
