import SwiftUI
import UniformTypeIdentifiers

struct CSVImportView: View {
    @State private var showImporter = false
    @State private var status: Status = .idle
    @State private var importedCount: Int = 0
    @State private var errors: [String] = []
    @State private var warnings: [String] = []
    @State private var showReportExporter = false
    @State private var reportDocument: TextDocument? = nil

    enum Status: Equatable {
        case idle
        case importing
        case success
        case failed(String)
    }

    var body: some View {
        Form {
            Section("Importer des questions (ZIP)") {
                Text("Le ZIP contient un CSV + des images. Le tout est importé et stocké localement puis fusionné avec le bundle (offline).")
                    .foregroundStyle(.secondary)

                Button {
                    showImporter = true
                } label: {
                    Label("Choisir un fichier ZIP...", systemImage: "square.and.arrow.down")
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
            id, level, category, subcategory, stem, choiceA, choiceB, choiceC, choiceD, answerIndex, explanation, difficulty, image
            """)
                .font(.footnote)
                .foregroundStyle(.secondary)

                Text("""
            • category : ex: Ethics, Quantitative Methods, FRA (alias accepté)
            • subcategory : texte libre (ex: Time Value of Money)
            • answerIndex : 0..3 ou A/B/C/D (multi : A|C ou 0|2)
            - image : nom de fichier dans le ZIP (ex: images/q1.png)
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

            if !warnings.isEmpty {
                Section("Avertissements") {
                    ForEach(warnings.prefix(30), id: \.self) { w in
                        Text(w).font(.footnote)
                    }
                    if warnings.count > 30 {
                        Text("… \(warnings.count - 30) avertissements supplémentaires")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !errors.isEmpty || !warnings.isEmpty {
                Section("Rapport") {
                    Button {
                        reportDocument = TextDocument(text: buildReport())
                        showReportExporter = true
                    } label: {
                        Label("Exporter le rapport", systemImage: "doc.plaintext")
                    }
                }
            }

            Section("Gestion") {
                Text("Questions importées actuellement : \(QuestionDiskStore.shared.load().count)")
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    QuestionDiskStore.shared.clear()
                    QuestionAssetStore.shared.clear()
                    importedCount = 0
                    errors = []
                    status = .idle
                } label: {
                    Label("Supprimer les questions importées", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Import ZIP")
        .fileExporter(
            isPresented: $showReportExporter,
            document: reportDocument ?? TextDocument(text: ""),
            contentType: .plainText,
            defaultFilename: "import_report"
        ) { _ in
            reportDocument = nil
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType.zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importZIP(url: url)
            case .failure(let error):
                status = .failed(error.localizedDescription)
            }
        }
    }

    private func importZIP(url: URL) {
        status = .importing
        errors = []
        warnings = []
        importedCount = 0

        Task {
            do {
                let canAccess = url.startAccessingSecurityScopedResource()
                defer { if canAccess { url.stopAccessingSecurityScopedResource() } }

                let importer = ZipQuestionImporter()
                let result = try importer.importQuestions(from: url)

                // merge avec existant
                let existing = QuestionDiskStore.shared.load()
                var dict = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
                for q in result.questions { dict[q.id] = q }
                QuestionDiskStore.shared.save(Array(dict.values))

                await MainActor.run {
                    importedCount = result.questions.count
                    errors = result.errors
                    warnings = result.warnings
                    status = .success
                }
            } catch {
                await MainActor.run {
                    status = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func buildReport() -> String {
        var lines: [String] = []
        lines.append("Import ZIP - Rapport")
        lines.append("Statut: \(statusText())")
        lines.append("Questions importées: \(importedCount)")
        lines.append("")

        if !errors.isEmpty {
            lines.append("Erreurs:")
            lines.append(contentsOf: errors.map { "- \($0)" })
            lines.append("")
        }

        if !warnings.isEmpty {
            lines.append("Avertissements:")
            lines.append(contentsOf: warnings.map { "- \($0)" })
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func statusText() -> String {
        switch status {
        case .idle: return "idle"
        case .importing: return "importing"
        case .success: return "success"
        case .failed(let msg): return "failed (\(msg))"
        }
    }
}

struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            text = string
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }
}
