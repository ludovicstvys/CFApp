import SwiftUI

struct ReportQuestionView: View {
    let question: CFAQuestion

    @Environment(\.dismiss) private var dismiss
    @State private var issueType: QuestionReport.IssueType = .typo
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Type de probleme") {
                    Picker("Type", selection: $issueType) {
                        ForEach(QuestionReport.IssueType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Details") {
                    TextField("Decris le probleme (optionnel)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Question") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(question.stem)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(question.category.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if let sub = question.subcategory,
                           !sub.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(sub)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Text("Les signalements sont stockes localement. Exportez-les depuis Reglages.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Signaler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Envoyer") { submit() }
                        .disabled(!canSubmit)
                }
            }
        }
    }

    private var canSubmit: Bool {
        if issueType == .other {
            return !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private func submit() {
        let report = QuestionReport(question: question, issueType: issueType, note: note)
        QuestionReportStore.shared.saveReport(report)
        Haptics.success()
        dismiss()
    }
}
