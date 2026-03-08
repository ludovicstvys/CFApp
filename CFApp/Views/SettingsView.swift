import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeManager

    @State private var showExporter = false
    @State private var exportDocument: CSVDocument? = nil
    @State private var exportName: String = "export"
    @State private var reportCount: Int = 0

    @State private var showStatsExporter = false
    @State private var showStatsImporter = false
    @State private var statsDocument: StatsDocument? = nil
    @State private var statsStatusMessage: String? = nil
    @State private var toastMessage: String? = nil
    @State private var toastTone: ToastBannerView.Tone = .info

    var body: some View {
        Form {
            Section("Apparence") {
                Picker("Theme", selection: Binding(
                    get: { theme.preference },
                    set: { theme.preference = $0 }
                )) {
                    ForEach(ThemePreference.allCases) { p in
                        Text(p.title).tag(p)
                    }
                }
            }

            Section("Statistiques") {
                Button {
                    exportStats()
                } label: {
                    Label("Exporter les statistiques (.json)", systemImage: "square.and.arrow.up")
                }
                .appActionButton()

                Button {
                    showStatsImporter = true
                } label: {
                    Label("Importer les statistiques (.json)", systemImage: "square.and.arrow.down")
                }
                .appActionButton()

                if let statsStatusMessage {
                    Text(statsStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Signalements") {
                Text("Signalements en attente : \(reportCount)")
                    .foregroundStyle(.secondary)

                Button {
                    exportReports()
                } label: {
                    Label("Exporter les signalements (CSV)", systemImage: "square.and.arrow.up")
                }
                .appActionButton()
                .disabled(reportCount == 0)
            }
        }
        .navigationTitle(String(localized: "app.settings.title", defaultValue: "Reglages"))
        .task {
            refreshReportCount()
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument ?? CSVDocument(text: ""),
            contentType: .commaSeparatedText,
            defaultFilename: exportName
        ) { result in
            exportDocument = nil
            handleExportResult(result)
        }
        .fileExporter(
            isPresented: $showStatsExporter,
            document: statsDocument ?? StatsDocument(data: Data()),
            contentType: .json,
            defaultFilename: "cfapp_stats"
        ) { result in
            statsDocument = nil
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $showStatsImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importStats(from: url)
            case .failure(let error):
                statsStatusMessage = "Import annule: \(error.localizedDescription)"
                showToast("Import annule.", tone: .error)
            }
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                ToastBannerView(message: toastMessage, tone: toastTone)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: toastMessage)
    }

    private func exportStats() {
        DispatchQueue.global(qos: .userInitiated).async {
            let attempts = AppDependencies.shared.statsStore.loadAttempts()
            let payload = StatsTransferPayload(
                schemaVersion: 1,
                exportedAt: Date(),
                attempts: attempts
            )

            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(payload)

                DispatchQueue.main.async {
                    statsDocument = StatsDocument(data: data)
                    showStatsExporter = true
                    statsStatusMessage = "Export termine: \(attempts.count) tentatives."
                    showToast("Fichier de statistiques pret.", tone: .success)
                }
            } catch {
                DispatchQueue.main.async {
                    statsStatusMessage = "Echec export statistiques: \(error.localizedDescription)"
                    showToast("Echec export statistiques.", tone: .error)
                }
            }
        }
    }

    private func exportReports() {
        DispatchQueue.global(qos: .userInitiated).async {
            let reports = AppDependencies.shared.questionReportStore.loadReports()
            let csv = CSVExportService.exportReports(reports)
            DispatchQueue.main.async {
                exportDocument = CSVDocument(text: csv)
                exportName = "question_reports"
                showExporter = true
                showToast("Fichier de signalements pret.", tone: .success)
            }
        }
    }

    private func importStats(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let canAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if canAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let data = try Data(contentsOf: url)
                let attempts = try decodeStatsAttempts(from: data)
                AppDependencies.shared.statsStore.saveAllAttempts(attempts)

                DispatchQueue.main.async {
                    statsStatusMessage = "Import termine: \(attempts.count) tentatives."
                    showToast("Import statistiques termine.", tone: .success)
                }
            } catch {
                DispatchQueue.main.async {
                    statsStatusMessage = "Import statistiques echoue: \(error.localizedDescription)"
                    showToast("Import statistiques echoue.", tone: .error)
                }
            }
        }
    }

    private func decodeStatsAttempts(from data: Data) throws -> [QuizAttempt] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let payload = try? decoder.decode(StatsTransferPayload.self, from: data) {
            return payload.attempts
        }
        if let attempts = try? decoder.decode([QuizAttempt].self, from: data) {
            return attempts
        }

        throw StatsTransferError.invalidFormat
    }

    private func refreshReportCount() {
        reportCount = AppDependencies.shared.questionReportStore.loadReports().count
    }

    private func handleExportResult(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            showToast("Export enregistre: \(url.lastPathComponent)", tone: .success)
        case .failure:
            showToast("Export annule ou echoue.", tone: .error)
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

private struct StatsTransferPayload: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let attempts: [QuizAttempt]
}

private enum StatsTransferError: LocalizedError {
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Format de fichier statistiques invalide."
        }
    }
}

struct StatsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
