import SwiftUI
import UniformTypeIdentifiers

struct CSVImportView: View {
    @State private var showImporter = false
    @State private var status: Status = .idle
    @State private var importedCount: Int = 0
    @State private var errors: [String] = []

    enum Status: Equatable {
        case idle
        case importing
        case success
        case failed(String)
    }

    var body: some View {
        Form {
            Section("Importer des questions (CSV)") {
                Text("Le CSV est importé et stocké localement. Ces questions sont ensuite fusionnées avec celles du bundle (offline).")
                    .foregroundStyle(.secondary)

                Button {
                    showImporter = true
                } label: {
                    Label("Choisir un fichier CSV…", systemImage: "square.and.arrow.down")
                }

                if status == .importing {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Import en cours…").foregroundStyle(.secondary)
                    }
                }

                if importedCount > 0, status == .success {
                    Text("✅ Import terminé : \(importedCount) questions importées.")
                        .font(.subheadline.weight(.semibold))
                }

                if case .failed(let msg) = status {
                    Text("❌ \(msg)")
                        .foregroundStyle(.red)
                }
            }

            Section("Format attendu") {
                Text("""
            En-tête recommandé :
            id, level, category, subcategory, stem, choiceA, choiceB, choiceC, choiceD, answerIndex, explanation, difficulty
            """)
                .font(.footnote)
                .foregroundStyle(.secondary)

                Text("""
            • category : ex: Ethics, Quantitative Methods, FRA (alias accepté)
            • subcategory : texte libre (ex: Time Value of Money)
            • answerIndex : 0..3 ou A/B/C/D (multi : A|C ou 0|2)
            """)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }


            if !errors.isEmpty {
                Section("Erreurs") {
                    ForEach(errors.prefix(30), id: \.self) { e in
                        Text(e).font(.footnote)
                    }
                    if errors.count > 30 {
                        Text("… \(errors.count - 30) erreurs supplémentaires")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Gestion") {
                Text("Questions importées actuellement : \(QuestionDiskStore.shared.load().count)")
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    QuestionDiskStore.shared.clear()
                    importedCount = 0
                    errors = []
                    status = .idle
                } label: {
                    Label("Supprimer les questions importées", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Import CSV")
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importCSV(url: url)
            case .failure(let error):
                status = .failed(error.localizedDescription)
            }
        }
    }

    private func importCSV(url: URL) {
        status = .importing
        errors = []
        importedCount = 0

        Task {
            do {
                let canAccess = url.startAccessingSecurityScopedResource()
                defer { if canAccess { url.stopAccessingSecurityScopedResource() } }

                let data = try Data(contentsOf: url)
                let importer = CSVQuestionImporter()
                let result = try importer.importQuestions(from: data)

                // merge avec existant
                let existing = QuestionDiskStore.shared.load()
                var dict = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
                for q in result.questions { dict[q.id] = q }
                QuestionDiskStore.shared.save(Array(dict.values))

                await MainActor.run {
                    importedCount = result.questions.count
                    errors = result.errors
                    status = .success
                }
            } catch {
                await MainActor.run {
                    status = .failed(error.localizedDescription)
                }
            }
        }
    }
}
