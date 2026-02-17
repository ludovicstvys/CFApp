import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var commandRouter: AppCommandRouter

    @State private var showExporter = false
    @State private var exportDocument: CSVDocument? = nil
    @State private var exportName: String = "export"
    @State private var questionCount: Int? = nil
    @State private var questionCounts: [CFALevel: Int] = [:]
    @State private var questionCountLoadFailed = false
    @State private var reportCount: Int = 0
    @State private var confirmClearReports = false
    @State private var showCSVImportScreen = false

    @State private var showBackupExporter = false
    @State private var showBackupImporter = false
    @State private var backupDocument: BackupDocument? = nil
    @State private var backupStatusMessage: String? = nil

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

            Section("Donnees") {
                Text("Les questions du niveau 1 sont chargees depuis un JSON embarque. L'import ZIP ajoute des questions et images locales.")
                    .foregroundStyle(.secondary)

                Group {
                    if let questionCount {
                        Text("Questions disponibles (base + importees) : \(questionCount)")
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(CFALevel.allCases) { level in
                                Text("\(level.title) : \(questionCounts[level, default: 0])")
                            }
                        }
                    } else if questionCountLoadFailed {
                        Text("Questions disponibles : erreur de chargement")
                    } else {
                        Text("Questions disponibles : ...")
                    }
                }
                .foregroundStyle(.secondary)

                NavigationLink {
                    CSVImportView()
                } label: {
                    Label("Importer des questions (ZIP)", systemImage: "square.and.arrow.down")
                }

                Button {
                    showCSVImportScreen = true
                } label: {
                    Label("Ouvrir l'import ZIP", systemImage: "tray.and.arrow.down")
                }
            }

            Section("Formules") {
                NavigationLink {
                    FormulasView()
                } label: {
                    Label("Voir les formules par topic", systemImage: "function")
                }
                Text("Les formules sont chargees depuis un JSON embarque.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Export CSV") {
                Button {
                    exportQuestions()
                } label: {
                    Label("Exporter les questions (CSV)", systemImage: "square.and.arrow.up")
                }

                Button {
                    exportAttempts()
                } label: {
                    Label("Exporter les statistiques (CSV)", systemImage: "chart.line.uptrend.xyaxis")
                }
            }

            Section("Sauvegarde complete") {
                Button {
                    exportFullBackup()
                } label: {
                    Label("Exporter sauvegarde (.json)", systemImage: "externaldrive.badge.plus")
                }

                Button {
                    showBackupImporter = true
                } label: {
                    Label("Importer sauvegarde (.json)", systemImage: "externaldrive.badge.checkmark")
                }

                if let backupStatusMessage {
                    Text(backupStatusMessage)
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
                .disabled(reportCount == 0)

                Button(role: .destructive) {
                    confirmClearReports = true
                } label: {
                    Label("Effacer les signalements", systemImage: "trash")
                }
                .disabled(reportCount == 0)
            }

            Section("Roadmap") {
                Text("CI multi-plateforme, cache image async, SRS avance, backup global, raccourcis macOS, et mock exam ont ete ajoutes.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "app.settings.title", defaultValue: "Reglages"))
        .task {
            if questionCount == nil && !questionCountLoadFailed {
                loadQuestionCount()
            }
            refreshReportCount()
        }
        .onChange(of: commandRouter.openImportRequestId) { _ in
            if commandRouter.selectedTab == .settings {
                showCSVImportScreen = true
            }
        }
        .navigationDestination(isPresented: $showCSVImportScreen) {
            CSVImportView()
        }
        .confirmationDialog("Supprimer les signalements ?", isPresented: $confirmClearReports, titleVisibility: .visible) {
            Button("Tout effacer", role: .destructive) {
                clearReports()
            }
            Button("Annuler", role: .cancel) {}
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument ?? CSVDocument(text: ""),
            contentType: .commaSeparatedText,
            defaultFilename: exportName
        ) { _ in
            exportDocument = nil
        }
        .fileExporter(
            isPresented: $showBackupExporter,
            document: backupDocument ?? BackupDocument(data: Data()),
            contentType: .json,
            defaultFilename: "cfapp_backup"
        ) { _ in
            backupDocument = nil
        }
        .fileImporter(
            isPresented: $showBackupImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importFullBackup(from: url)
            case .failure(let error):
                backupStatusMessage = "Import annule: \(error.localizedDescription)"
            }
        }
    }

    private func exportQuestions() {
        let repo = AppDependencies.shared.questionRepository
        let questions = (try? repo.loadAllQuestions()) ?? []
        let csv = CSVExportService.exportQuestions(questions)
        exportDocument = CSVDocument(text: csv)
        exportName = "questions"
        showExporter = true
    }

    private func exportAttempts() {
        let attempts = AppDependencies.shared.statsStore.loadAttempts()
        let csv = CSVExportService.exportAttempts(attempts)
        exportDocument = CSVDocument(text: csv)
        exportName = "attempts"
        showExporter = true
    }

    private func exportReports() {
        let reports = AppDependencies.shared.questionReportStore.loadReports()
        let csv = CSVExportService.exportReports(reports)
        exportDocument = CSVDocument(text: csv)
        exportName = "question_reports"
        showExporter = true
    }

    private func exportFullBackup() {
        do {
            let data = try AppBackupService.shared.exportBackupData()
            backupDocument = BackupDocument(data: data)
            showBackupExporter = true
            backupStatusMessage = "Sauvegarde prete a etre exportee."
        } catch {
            backupStatusMessage = "Echec export sauvegarde: \(error.localizedDescription)"
        }
    }

    private func importFullBackup(from url: URL) {
        Task {
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                let summary = try AppBackupService.shared.importBackupData(data)
                await MainActor.run {
                    if let importedTheme = ThemePreference(rawValue: UserDefaults.standard.integer(forKey: "cfaquiz.themePreference")) {
                        theme.preference = importedTheme
                    }
                    loadQuestionCount()
                    refreshReportCount()
                    backupStatusMessage = "Import termine: \(summary.attempts) attempts, \(summary.importedQuestions) questions importees."
                }
            } catch {
                await MainActor.run {
                    backupStatusMessage = "Import sauvegarde echoue: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadQuestionCount() {
        let repo = AppDependencies.shared.questionRepository
        do {
            let questions = try repo.loadAllQuestions()
            questionCount = questions.count
            questionCounts = Dictionary(grouping: questions, by: \.level)
                .mapValues { $0.count }
            questionCountLoadFailed = false
        } catch {
            questionCount = nil
            questionCounts = [:]
            questionCountLoadFailed = true
        }
    }

    private func refreshReportCount() {
        reportCount = AppDependencies.shared.questionReportStore.loadReports().count
    }

    private func clearReports() {
        AppDependencies.shared.questionReportStore.clear()
        refreshReportCount()
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

struct BackupDocument: FileDocument {
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
