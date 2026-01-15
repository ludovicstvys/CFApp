import SwiftUI

struct StatsView: View {
    @StateObject private var vm = StatsViewModel()
    @State private var confirmClear = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    StatPillView(title: "Tentatives", value: "\(vm.totalAttempts)", systemImage: "square.stack.3d.up.fill")
                    StatPillView(title: "Précision", value: "\(Int((vm.overallAccuracy * 100).rounded()))%", systemImage: "scope")
                    StatPillView(title: "Best", value: "\(Int((vm.bestScorePct * 100).rounded()))%", systemImage: "trophy.fill")
                }
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 8)
            }

            Section("Historique") {
                if vm.attempts.isEmpty {
                    Text("Aucune tentative pour le moment.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.attempts) { a in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(a.level.title) • \(a.mode.title)")
                                    .font(.headline)
                                Spacer()
                                Text("\(a.score)/\(a.total)")
                                    .font(.headline.monospacedDigit())
                            }

                            Text(dateLine(a))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(a.categories) { cat in
                                        Label(cat.shortName, systemImage: cat.systemImage)
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .background(Color.secondary.opacity(0.1), in: Capsule())
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmClear = true
                } label: {
                    Label("Effacer toutes les stats", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Statistiques")
        .onAppear { vm.refresh() }
        .confirmationDialog("Supprimer toutes les stats ?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Tout effacer", role: .destructive) { vm.clearAll() }
            Button("Annuler", role: .cancel) {}
        }
    }

    private func dateLine(_ a: QuizAttempt) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateStyle = .medium
        df.timeStyle = .short
        let mins = max(1, a.durationSeconds / 60)
        return "\(df.string(from: a.date)) • \(mins) min"
    }
}
