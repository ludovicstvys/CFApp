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
    @State private var showImporter = false
    @State private var showReportExporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import ZIP - Questions CFA")
                .font(.title2.weight(.bold))

            Text("Selectionnez un ZIP contenant un CSV + images. Les questions seront ajoutees au stockage local de l'app.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    showImporter = true
                } label: {
                    Label("Choisir un ZIP...", systemImage: "square.and.arrow.down")
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
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType.zip],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                vm.importZIP(url: url)
            } else if case .failure(let error) = result {
                vm.fail(with: error.localizedDescription)
            }
        }
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

    var hasReport: Bool {
        !errors.isEmpty || !warnings.isEmpty || status != .idle
    }

    func importZIP(url: URL) {
        status = .importing
        errors = []
        warnings = []

        Task {
            do {
                let canAccess = url.startAccessingSecurityScopedResource()
                defer { if canAccess { url.stopAccessingSecurityScopedResource() } }

                let importer = ZipQuestionImporter()
                let result = try importer.importQuestions(from: url)

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
