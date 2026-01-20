//
//  ContentView.swift
//  CFAppImporter
//
//  Created by Ludovic Saint-Yves on 16/01/2026.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = ImporterViewModel()
    @State private var showReportExporter = false
    @State private var showQuestionsExporter = false
    @State private var questionsDocument: CSVDocument? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            GroupBox("Dossier d'import") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(vm.importInboxPath)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text("Deposez un ZIP dans ce dossier. L'app importe le ZIP le plus recent.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Astuce: supprimez les anciens ZIPs ou renommez le nouveau fichier si besoin.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button {
                    vm.importFromInbox()
                } label: {
                    Label("Importer depuis le dossier", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)

                if vm.status == .importing {
                    ProgressView()
                }
            }

            if case .success(let count) = vm.status {
                Text("Import termine : \(count) questions importees.")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            if case .failed(let message) = vm.status {
                Text("Echec : \(message)")
                    .foregroundStyle(.red)
            }

            if !vm.errors.isEmpty {
                GroupBox("Erreurs (max 30)") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(vm.errors.prefix(30), id: \.self) { err in
                                Text(err).font(.footnote)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            }

            if !vm.warnings.isEmpty {
                GroupBox("Avertissements (max 30)") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(vm.warnings.prefix(30), id: \.self) { warn in
                                Text(warn).font(.footnote)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            }

            importStatus

            HStack(spacing: 12) {
                Button {
                    showReportExporter = true
                } label: {
                    Label("Exporter le rapport", systemImage: "doc.plaintext")
                }
                .disabled(!vm.hasReport)

                Button {
                    questionsDocument = CSVDocument(text: vm.buildQuestionsCSV())
                    showQuestionsExporter = true
                } label: {
                    Label("Exporter les questions (CSV)", systemImage: "square.and.arrow.up")
                }
                .disabled(vm.importedCount == 0)

                Button(role: .destructive) {
                    vm.clearImported()
                } label: {
                    Label("Vider les imports", systemImage: "trash")
                }
            }

            if !vm.categoryCounts.isEmpty {
                GroupBox("Repartition par categorie") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(vm.categoryCounts, id: \.category) { entry in
                            HStack {
                                Text(entry.category.shortName)
                                Spacer()
                                Text("\(entry.count)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            GroupBox("Questions importees") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Picker("Categorie", selection: $vm.selectedCategory) {
                            Text("Toutes").tag(Optional<CFACategory>.none)
                            ForEach(vm.availableCategories, id: \.self) { cat in
                                Text(cat.shortName).tag(Optional(cat))
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Sous-categorie", selection: $vm.selectedSubcategory) {
                            Text("Toutes").tag(Optional<String>.none)
                            ForEach(vm.availableSubcategories, id: \.self) { sub in
                                Text(sub).tag(Optional(sub))
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(vm.availableSubcategories.isEmpty)

                        Spacer()

                        Text("\(vm.filteredQuestions.count)/\(vm.importedCount)")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    List(vm.filteredQuestions) { question in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(question.stem)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 8) {
                                Text(question.level.title)
                                Text("•")
                                Text(question.category.shortName)
                                if let sub = question.subcategory,
                                   !sub.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("•")
                                    Text(sub)
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Text("Choix: \(question.choices.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.inset)
                    .frame(minHeight: 220, maxHeight: 320)
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 520)
        .fileExporter(
            isPresented: $showReportExporter,
            document: TextDocument(text: vm.buildReport()),
            contentType: .plainText,
            defaultFilename: "import_report"
        ) { _ in }
        .fileExporter(
            isPresented: $showQuestionsExporter,
            document: questionsDocument ?? CSVDocument(text: ""),
            contentType: .commaSeparatedText,
            defaultFilename: "questions_export"
        ) { _ in
            questionsDocument = nil
        }
        .onChange(of: vm.selectedCategory) { _, _ in
            vm.onCategoryChanged()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Import ZIP - Questions CFA")
                    .font(.title2.weight(.bold))
                Text("Placez un ZIP (CSV + images) dans le dossier d'import, puis lancez l'import.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .padding(10)
                .background(Color.accentColor.opacity(0.15), in: Circle())
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.14),
                    Color.green.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var importStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Questions importees : \(vm.importedCount)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let error = vm.importedLoadError {
                Text("Lecture impossible: \(error)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}

@MainActor
final class ImporterViewModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case importing
        case success(count: Int)
        case failed(String)
    }

    @Published var status: Status = .idle
    @Published var errors: [String] = []
    @Published var warnings: [String] = []
    @Published var importedCount: Int = 0
    @Published var importedLoadError: String? = nil
    @Published var questions: [CFAQuestion] = []
    @Published var selectedCategory: CFACategory? = nil
    @Published var selectedSubcategory: String? = nil

    init() {
        refreshImportedCount()
    }

    var importInboxPath: String {
        ImportPaths.importInbox.path
    }

    var hasReport: Bool {
        !errors.isEmpty || !warnings.isEmpty || status != .idle
    }

    func importFromInbox() {
        status = .importing
        errors = []
        warnings = []

        Task {
            do {
                guard ImportPaths.isValidRepoRoot(ImportPaths.repoRoot) else {
                    status = .failed("Repo introuvable. Definissez CFAPP_REPO_ROOT.")
                    return
                }

                ImportPaths.ensureDirectories()
                guard let zipURL = findLatestZip(in: ImportPaths.importInbox) else {
                    status = .failed("Aucun ZIP trouve dans le dossier d'import.")
                    return
                }

                let importer = ZipQuestionImporter()
                let result = try importer.importQuestions(from: zipURL)
                removeZipAfterImport(zipURL)

                let existing = try QuestionDiskStore.shared.loadOrThrow()
                let existingDeduped = QuestionDeduplicator.dedupe(existing)
                let merged = QuestionDeduplicator.merge(
                    existing: existingDeduped.questions,
                    incoming: result.questions
                )
                QuestionDiskStore.shared.save(merged.questions)

                let added = merged.questions.count - existingDeduped.questions.count
                status = .success(count: max(0, added))
                errors = result.errors
                warnings = result.warnings
                if merged.duplicates > 0 {
                    warnings.append("Doublons ignores (stem + 4 choix): \(merged.duplicates)")
                }
                refreshImportedCount()
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    func clearImported() {
        QuestionDiskStore.shared.clear()
        QuestionAssetStore.shared.clear()
        errors = []
        warnings = []
        status = .idle
        refreshImportedCount()
    }

    func fail(with message: String) {
        status = .failed(message)
    }

    func buildReport() -> String {
        var lines: [String] = []
        lines.append("Import ZIP - Rapport")
        lines.append("Statut: \(statusText())")
        if case .success(let count) = status {
            lines.append("Questions importees: \(count)")
        }
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

    func buildQuestionsCSV() -> String {
        let questions = QuestionDiskStore.shared.load()
        return CSVExportService.exportQuestions(questions)
    }

    func onCategoryChanged() {
        if let selectedSubcategory,
           !availableSubcategories.contains(selectedSubcategory) {
            self.selectedSubcategory = nil
        }
    }

    var filteredQuestions: [CFAQuestion] {
        questions.filter { q in
            if let selectedCategory, q.category != selectedCategory { return false }
            if let selectedSubcategory {
                let sub = (q.subcategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if sub != selectedSubcategory { return false }
            }
            return true
        }
        .sorted { lhs, rhs in
            if lhs.category.rawValue != rhs.category.rawValue {
                return lhs.category.rawValue < rhs.category.rawValue
            }
            return lhs.stem < rhs.stem
        }
    }

    var availableCategories: [CFACategory] {
        Array(Set(questions.map { $0.category }))
            .sorted { $0.rawValue < $1.rawValue }
    }

    var categoryCounts: [(category: CFACategory, count: Int)] {
        let counts = Dictionary(grouping: questions, by: \.category)
            .mapValues { $0.count }
        return counts
            .map { (category: $0.key, count: $0.value) }
            .sorted { $0.category.rawValue < $1.category.rawValue }
    }

    var availableSubcategories: [String] {
        let filtered = questions.filter { q in
            if let selectedCategory, q.category != selectedCategory { return false }
            return true
        }
        let subs = filtered.compactMap { q in
            q.subcategory?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return Array(Set(subs)).filter { !$0.isEmpty }.sorted()
    }

    private func statusText() -> String {
        switch status {
        case .idle: return "idle"
        case .importing: return "importing"
        case .success: return "success"
        case .failed(let msg): return "failed (\(msg))"
        }
    }

    private func findLatestZip(in dir: URL) -> URL? {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let zips = items.filter { $0.pathExtension.lowercased() == "zip" }
        let sorted = zips.sorted { lhs, rhs in
            let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lDate > rDate
        }
        return sorted.first
    }

    private func removeZipAfterImport(_ url: URL) {
        let fm = FileManager.default
        try? fm.removeItem(at: url)
    }

    private func refreshImportedCount() {
        do {
            let loaded = try QuestionDiskStore.shared.loadOrThrow()
            questions = loaded
            importedCount = loaded.count
            importedLoadError = nil
        } catch {
            importedCount = 0
            questions = []
            importedLoadError = error.localizedDescription
        }
        normalizeFilters()
    }

    private func normalizeFilters() {
        if let selectedCategory, !availableCategories.contains(selectedCategory) {
            self.selectedCategory = nil
        }
        onCategoryChanged()
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

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

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
