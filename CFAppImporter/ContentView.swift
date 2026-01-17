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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import ZIP - Questions CFA")
                .font(.title2.weight(.bold))

            Text("Placez un ZIP (CSV + images) dans le dossier d'import, puis lancez l'import.")
                .foregroundStyle(.secondary)

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

            HStack(spacing: 12) {
                Button {
                    showReportExporter = true
                } label: {
                    Label("Exporter le rapport", systemImage: "doc.plaintext")
                }
                .disabled(!vm.hasReport)

                Button(role: .destructive) {
                    vm.clearImported()
                } label: {
                    Label("Vider les imports", systemImage: "trash")
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

                let existing = QuestionDiskStore.shared.load()
                var dict = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
                for q in result.questions { dict[q.id] = q }
                QuestionDiskStore.shared.save(Array(dict.values))

                status = .success(count: result.questions.count)
                errors = result.errors
                warnings = result.warnings
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
