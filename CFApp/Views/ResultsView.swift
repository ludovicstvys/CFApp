import SwiftUI

struct ResultsView: View {
    let config: QuizConfig
    let score: Int
    let total: Int
    let records: [QuizViewModel.AnswerRecord]
    let onRestart: () -> Void
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showReview = false

    private var pct: Double {
        guard total > 0 else { return 0 }
        return Double(score) / Double(total)
    }

    private var pctText: String {
        "\(Int((pct * 100).rounded()))%"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                HStack(spacing: 12) {
                    StatPillView(title: "Score", value: "\(score)/\(total)", systemImage: "checkmark.circle.fill")
                    StatPillView(title: "Taux", value: pctText, systemImage: "percent")
                }

                GroupBox("Détail par catégorie") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(categoryBreakdown.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { cat, tuple in
                            HStack {
                                Label(cat.shortName, systemImage: cat.systemImage)
                                Spacer()
                                Text("\(tuple.correct)/\(tuple.total)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: tuple.progress)
                        }
                    }
                }

                if !subcategoryBreakdown.isEmpty {
                    GroupBox("Détail par sous-catégorie") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(subcategoryBreakdown.sorted(by: { $0.key < $1.key }), id: \.key) { sub, tuple in
                                HStack {
                                    Text(sub).font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text("\(tuple.correct)/\(tuple.total)")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                ProgressView(value: tuple.progress)
                            }
                        }
                    }
                }

                GroupBox("Actions") {
                    VStack(spacing: 10) {
                        PrimaryButton(title: "Revoir les questions", systemImage: "list.bullet.rectangle") {
                            showReview = true
                        }
                        PrimaryButton(title: "Recommencer", systemImage: "arrow.clockwise") {
                            onRestart()
                        }
                        Button(role: .cancel) {
                            dismiss()
                        } label: {
                            Text("Retour")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Résultats")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showReview) {
            ReviewView(records: records)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Terminé ✅")
                .font(.largeTitle.bold())

            Text("Mode : \(config.mode.title) • \(config.level.title)")
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }

    private var categoryBreakdown: [CFACategory: (correct: Int, total: Int, progress: Double)] {
        var dict: [CFACategory: (Int, Int)] = [:]
        for r in records {
            dict[r.category, default: (0, 0)].1 += 1
            if r.isCorrect { dict[r.category, default: (0, 0)].0 += 1 }
        }
        return dict.mapValues { c, t in
            let p = t == 0 ? 0 : Double(c) / Double(t)
            return (c, t, p)
        }
    }

    private var subcategoryBreakdown: [String: (correct: Int, total: Int, progress: Double)] {
        var dict: [String: (Int, Int)] = [:]
        for r in records {
            let sub = (r.subcategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sub.isEmpty else { continue }
            dict[sub, default: (0, 0)].1 += 1
            if r.isCorrect { dict[sub, default: (0, 0)].0 += 1 }
        }
        return dict.mapValues { c, t in
            let p = t == 0 ? 0 : Double(c) / Double(t)
            return (c, t, p)
        }
    }
}
