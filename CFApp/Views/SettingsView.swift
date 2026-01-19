import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeManager
    @State private var showExporter = false
    @State private var exportDocument: CSVDocument? = nil
    @State private var exportName: String = "export"
    @State private var questionCount: Int? = nil
    @State private var questionCounts: [CFALevel: Int] = [:]
    @State private var questionCountLoadFailed = false

    var body: some View {
        Form {
            Section("Apparence") {
                Picker("Thème", selection: Binding(
                    get: { theme.preference },
                    set: { theme.preference = $0 }
                )) {
                    ForEach(ThemePreference.allCases) { p in
                        Text(p.title).tag(p)
                    }
                }
            }

            Section("Données") {
                Text("Les questions du niveau 1 sont chargées depuis un JSON embarqué (offline). L'import ZIP ajoute des questions et images locales.")
                    .foregroundStyle(.secondary)

                Group {
                    if let questionCount {
                        Text("Questions disponibles (base + importées) : \(questionCount)")
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(CFALevel.allCases) { level in
                                Text("\(level.title) : \(questionCounts[level, default: 0])")
                            }
                        }
                    } else if questionCountLoadFailed {
                        Text("Questions disponibles : erreur de chargement")
                    } else {
                        Text("Questions disponibles : …")
                    }
                }
                .foregroundStyle(.secondary)

                NavigationLink {
                    CSVImportView()
                } label: {
                    Label("Importer des questions (ZIP)", systemImage: "square.and.arrow.down")
                }
            }

            Section("Export") {
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

            Section("À venir (idées)") {
                Text("• Gamification (streak, badges)\n• Synchronisation multi-appareils\n• Génération de tests par LOS\n• Import/export CSV/JSON\n• Mode “mock exam” multi-sessions")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Réglages")
        .task {
            if questionCount == nil && !questionCountLoadFailed {
                loadQuestionCount()
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument ?? CSVDocument(text: ""),
            contentType: .commaSeparatedText,
            defaultFilename: exportName
        ) { _ in
            exportDocument = nil
        }
    }

    private func exportQuestions() {
        let repo = HybridQuestionRepository()
        let questions = (try? repo.loadAllQuestions()) ?? []
        let csv = CSVExportService.exportQuestions(questions)
        exportDocument = CSVDocument(text: csv)
        exportName = "questions"
        showExporter = true
    }

    private func exportAttempts() {
        let attempts = StatsStore.shared.loadAttempts()
        let csv = CSVExportService.exportAttempts(attempts)
        exportDocument = CSVDocument(text: csv)
        exportName = "attempts"
        showExporter = true
    }

    private func loadQuestionCount() {
        let repo = HybridQuestionRepository()
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
