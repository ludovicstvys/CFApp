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
    @State private var isDropTarget = false
    @State private var toastMessage: String? = nil
    @State private var toastTone: ToastBannerView.Tone = .info

    enum Status: Equatable {
        case idle
        case importing
        case success
        case failed(String)
    }

    var body: some View {
        Form {
            Section("Importer des questions (ZIP/CSV)") {
                Text("Le ZIP peut contenir un CSV + des images. Le tout est importe et stocke localement, puis fusionne avec le bundle.")
                    .foregroundStyle(.secondary)

                Button {
                    showImporter = true
                } label: {
                    Label("Choisir un fichier ZIP ou CSV...", systemImage: "square.and.arrow.down")
                }
                .accessibilityHint("Ouvre le selecteur de fichiers")

                Text("Sur macOS, vous pouvez aussi glisser-deposer un fichier ici.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if status == .importing {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Import en cours...").foregroundStyle(.secondary)
                    }
                }

                if importedCount > 0, status == .success {
                    Text("Import termine : \(importedCount) questions importees.")
                        .font(.subheadline.weight(.semibold))
                }

                if case .failed(let msg) = status {
                    Text("Echec: \(msg)")
                        .foregroundStyle(.red)
                }
            }

            Section("Format attendu") {
                Text("""
            En-tete recommande :
            id, level, category, subcategory, stem, choiceA, choiceB, choiceC, choiceD, answerIndex, explanation, difficulty, image
            """)
                .font(.footnote)
                .foregroundStyle(.secondary)

                Text("""
            • category : ex: Ethics, Quantitative Methods, FRA (alias accepte)
            • subcategory : texte libre (ex: Time Value of Money)
            • answerIndex : 0..3 ou A/B/C/D (multi : A|C ou 0|2)
            • image : nom de fichier dans le ZIP (ex: images/q1.png)
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
                        Text("... \(errors.count - 30) erreurs supplementaires")
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
                        Text("... \(warnings.count - 30) avertissements supplementaires")
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
                Text("Questions importees actuellement : \(AppDependencies.shared.questionDiskStore.load().count)")
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    AppDependencies.shared.questionDiskStore.clear()
                    QuestionAssetStore.shared.clear()
                    importedCount = 0
                    errors = []
                    warnings = []
                    status = .idle
                } label: {
                    Label("Supprimer les questions importees", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Import ZIP/CSV")
        .overlay(dropOverlay)
        .overlay(alignment: .bottom) {
            if let toastMessage {
                ToastBannerView(message: toastMessage, tone: toastTone)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: toastMessage)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTarget) { providers in
            handleDrop(providers: providers)
        }
        .fileExporter(
            isPresented: $showReportExporter,
            document: reportDocument ?? TextDocument(text: ""),
            contentType: .plainText,
            defaultFilename: "import_report"
        ) { result in
            reportDocument = nil
            switch result {
            case .success(let url):
                showToast("Rapport exporte: \(url.lastPathComponent)", tone: .success)
            case .failure:
                showToast("Export du rapport annule ou echoue.", tone: .error)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType.zip, UTType.commaSeparatedText, UTType.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                handlePickedFile(url: url)
            case .failure(let error):
                status = .failed(error.localizedDescription)
                showToast("Import annule.", tone: .error)
            }
        }
    }

    @ViewBuilder
    private var dropOverlay: some View {
        if isDropTarget {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                .padding(8)
                .overlay {
                    Text("Deposez un ZIP/CSV pour importer")
                        .font(.headline)
                        .padding(12)
                        .background(.thinMaterial, in: Capsule())
                }
                .allowsHitTesting(false)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let error {
                DispatchQueue.main.async {
                    status = .failed(error.localizedDescription)
                    showToast("Erreur de lecture du fichier.", tone: .error)
                }
                return
            }

            guard let url = extractURL(from: item) else {
                DispatchQueue.main.async {
                    status = .failed("Impossible de lire l'URL du fichier depose.")
                    showToast("Fichier depose invalide.", tone: .error)
                }
                return
            }

            DispatchQueue.main.async {
                handlePickedFile(url: url)
            }
        }
        return true
    }

    private func extractURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let nsurl = item as? NSURL { return nsurl as URL }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        if let string = item as? String, let url = URL(string: string) {
            return url
        }
        return nil
    }

    private func handlePickedFile(url: URL) {
        let ext = url.pathExtension.lowercased()
        if ext == "zip" {
            importZIP(url: url)
        } else if ext == "csv" || ext == "txt" {
            importCSV(url: url)
        } else {
            status = .failed("Type de fichier non supporte: .\(ext)")
            showToast("Type de fichier non supporte: .\(ext)", tone: .error)
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
                defer {
                    if canAccess { url.stopAccessingSecurityScopedResource() }
                }

                let importer = ZipQuestionImporter()
                let result = try importer.importQuestions(from: url)

                let existing = AppDependencies.shared.questionDiskStore.load()
                var dict = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
                for q in result.questions { dict[q.id] = q }
                AppDependencies.shared.questionDiskStore.save(Array(dict.values))

                await MainActor.run {
                    importedCount = result.questions.count
                    errors = result.errors
                    warnings = result.warnings
                    status = .success
                    if result.errors.isEmpty {
                        showToast("Import termine: \(result.questions.count) questions.", tone: .success)
                    } else {
                        showToast("Import termine avec erreurs (\(result.errors.count)).", tone: .error)
                    }
                }
            } catch {
                await MainActor.run {
                    status = .failed(error.localizedDescription)
                    showToast("Import ZIP echoue.", tone: .error)
                }
            }
        }
    }

    private func importCSV(url: URL) {
        status = .importing
        errors = []
        warnings = []
        importedCount = 0

        Task {
            do {
                let canAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if canAccess { url.stopAccessingSecurityScopedResource() }
                }

                let data = try Data(contentsOf: url)
                let result = try CSVQuestionImporter().importQuestions(from: data)

                let existing = AppDependencies.shared.questionDiskStore.load()
                var dict = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
                for q in result.questions { dict[q.id] = q }
                AppDependencies.shared.questionDiskStore.save(Array(dict.values))

                await MainActor.run {
                    importedCount = result.questions.count
                    errors = result.errors
                    warnings = result.warnings
                    status = .success
                    if result.errors.isEmpty {
                        showToast("Import termine: \(result.questions.count) questions.", tone: .success)
                    } else {
                        showToast("Import termine avec erreurs (\(result.errors.count)).", tone: .error)
                    }
                }
            } catch {
                await MainActor.run {
                    status = .failed(error.localizedDescription)
                    showToast("Import CSV echoue.", tone: .error)
                }
            }
        }
    }

    private func buildReport() -> String {
        var lines: [String] = []
        lines.append("Import ZIP/CSV - Rapport")
        lines.append("Statut: \(statusText())")
        lines.append("Questions importees: \(importedCount)")
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

    private func showToast(_ message: String, tone: ToastBannerView.Tone) {
        toastTone = tone
        toastMessage = message
        let currentMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if toastMessage == currentMessage {
                toastMessage = nil
            }
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
