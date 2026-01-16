import SwiftUI

struct ReviewView: View {
    let records: [QuizViewModel.AnswerRecord]

    @State private var showIncorrectOnly = false
    @State private var selectedCategory: CFACategory? = nil
    @State private var selectedSubcategory: String? = nil

    var body: some View {
        List {
            Section("Filtres") {
                Toggle("Afficher uniquement les erreurs", isOn: $showIncorrectOnly)

                Picker("Catégorie", selection: $selectedCategory) {
                    Text("Toutes").tag(Optional<CFACategory>.none)
                    ForEach(availableCategories, id: \.self) { cat in
                        Text(cat.shortName).tag(Optional(cat))
                    }
                }

                Picker("Sous-catégorie", selection: $selectedSubcategory) {
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
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedCategory) { _ in
            if let selectedSubcategory, !availableSubcategories.contains(selectedSubcategory) {
                self.selectedSubcategory = nil
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

    private var filteredRecords: [QuizViewModel.AnswerRecord] {
        records.filter { r in
            if showIncorrectOnly, r.isCorrect { return false }
            if let selectedCategory, r.category != selectedCategory { return false }
            if let selectedSubcategory {
                let sub = (r.subcategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if sub != selectedSubcategory { return false }
            }
            return true
        }
    }

    private var availableCategories: [CFACategory] {
        Array(Set(records.map { $0.category })).sorted { $0.rawValue < $1.rawValue }
    }

    private var availableSubcategories: [String] {
        let filtered = records.filter { r in
            if let selectedCategory, r.category != selectedCategory { return false }
            return true
        }
        let subs = filtered.compactMap { $0.subcategory?.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Array(Set(subs)).filter { !$0.isEmpty }.sorted()
    }
}
