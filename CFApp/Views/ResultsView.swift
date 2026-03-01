import SwiftUI

struct ResultsView: View {
    let config: QuizConfig
    let score: Int
    let total: Int
    let records: [QuizViewModel.AnswerRecord]
    let answeredCount: Int
    let unansweredCount: Int
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

                GroupBox("Detail de la session") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Questions repondues")
                            Spacer()
                            Text("\(answeredCount)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Questions blanches")
                            Spacer()
                            Text("\(unansweredCount)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if let limit = config.effectiveTimeLimitSeconds, limit > 0 {
                            HStack {
                                Text("Temps alloue")
                                Spacer()
                                Text(formatMinutes(limit))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                GroupBox("Detail par categorie") {
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
                    GroupBox("Detail par sous-categorie") {
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
                            onDone()
                        } label: {
                            Text("Retour")
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: AppButtonMetrics.minHeight)
                        }
                        .appActionButton()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Resultats")
#if os(iOS) || os(tvOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .navigationDestination(isPresented: $showReview) {
            ReviewView(records: records)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Termine")
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
        return dict.mapValues { tuple in
            let (c, t) = tuple
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
        return dict.mapValues { tuple in
            let (c, t) = tuple
            let p = t == 0 ? 0 : Double(c) / Double(t)
            return (c, t, p)
        }
    }

    private func formatMinutes(_ seconds: Int) -> String {
        let mins = seconds / 60
        let sec = seconds % 60
        return String(format: "%d:%02d", mins, sec)
    }
}
