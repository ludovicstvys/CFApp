import SwiftUI

struct ReviewView: View {
    let records: [QuizViewModel.AnswerRecord]

    var body: some View {
        List {
            ForEach(records) { r in
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(r.stem)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)

                        if let sub = r.subcategory, !sub.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(sub)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(r.choices.enumerated()), id: \.offset) { idx, choice in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: marker(for: r, idx: idx))
                                        .foregroundStyle(color(for: r, idx: idx))
                                        .padding(.top, 2)
                                    Text(choice)
                                }
                            }
                        }

                        Text(r.explanation)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Label(r.category.shortName, systemImage: r.category.systemImage)
                }
            }
        }
        .navigationTitle("Revue")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func marker(for r: QuizViewModel.AnswerRecord, idx: Int) -> String {
        if r.correctIndices.contains(idx) { return "checkmark.circle.fill" }
        if r.selectedIndices.contains(idx) { return "xmark.circle.fill" }
        return "circle"
    }

    private func color(for r: QuizViewModel.AnswerRecord, idx: Int) -> Color {
        if r.correctIndices.contains(idx) { return .green }
        if r.selectedIndices.contains(idx) { return .red }
        return .secondary
    }
}
