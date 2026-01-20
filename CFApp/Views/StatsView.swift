import SwiftUI
#if canImport(Charts)
import Charts
#endif

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

                HStack(spacing: 12) {
                    StatPillView(title: "Streak", value: "\(vm.streakDays) j", systemImage: "flame.fill")
                    StatPillView(title: "Temps/Q", value: formatTime(vm.averageSecondsPerQuestion), systemImage: "timer")
                }
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 6)
            }

            Section("Objectif hebdo") {
                Stepper("Objectif : \(vm.weeklyGoal) questions", value: $vm.weeklyGoal, in: 0...500, step: 5)

                if vm.weeklyGoal > 0 {
                    ProgressView(value: vm.weeklyProgress)
                    Text("\(vm.weeklyQuestionsAnswered)/\(vm.weeklyGoal) cette semaine")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Objectif désactivé.")
                        .foregroundStyle(.secondary)
                }
            }

            if !vm.weeklyGoalAlerts.isEmpty {
                Section("Alertes hebdo") {
                    ForEach(vm.weeklyGoalAlerts) { alert in
                        HStack {
                            Label(alert.category.shortName, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Spacer()
                            Text("\(alert.answered)/\(alert.goal)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text("Il manque \(alert.remaining) question(s) cette semaine.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Objectifs hebdo par catégorie") {
                if vm.availableCategories.isEmpty {
                    Text("Aucune catégorie chargée.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.availableCategories) { cat in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(cat.shortName, systemImage: cat.systemImage)
                                Spacer()
                                let answered = vm.weeklyAnswered(for: cat)
                                let goal = vm.weeklyGoal(for: cat)
                                Text("\(answered)/\(goal)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            Stepper(
                                "Objectif : \(vm.weeklyGoal(for: cat)) questions",
                                value: bindingForCategoryGoal(cat),
                                in: 0...500,
                                step: 5
                            )

                            if vm.weeklyGoal(for: cat) > 0 {
                                ProgressView(value: vm.weeklyProgress(for: cat))
                                if vm.weeklyAnswered(for: cat) >= vm.weeklyGoal(for: cat) {
                                    Text("Objectif atteint.")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    let remaining = vm.weeklyGoal(for: cat) - vm.weeklyAnswered(for: cat)
                                    Text("Il manque \(remaining) question(s) cette semaine.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Objectif désactivé.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Tendances") {
                #if canImport(Charts)
                if #available(iOS 16.0, *) {
                    if vm.accuracySeries.isEmpty {
                        Text("Pas assez de données pour afficher un graphique.")
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(vm.accuracySeries) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Précision", point.accuracy)
                            )
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Précision", point.accuracy)
                            )
                        }
                        .chartYScale(domain: 0...1)
                        .frame(height: 200)
                    }
                } else {
                    Text("Graphiques disponibles à partir d’iOS 16.")
                        .foregroundStyle(.secondary)
                }
                #else
                Text("Graphiques non disponibles sur cette plateforme.")
                    .foregroundStyle(.secondary)
                #endif
            }

            Section("Précision par thème") {
                if vm.categoryAccuracy.isEmpty {
                    Text("Aucune donnée par thème.")
                        .foregroundStyle(.secondary)
                } else {
                    #if canImport(Charts)
                    if #available(iOS 16.0, *) {
                        Chart(vm.categoryAccuracy) { point in
                            BarMark(
                                x: .value("Catégorie", point.category.shortName),
                                y: .value("Précision", point.accuracy)
                            )
                        }
                        .chartYScale(domain: 0...1)
                        .frame(height: 220)
                    }
                    #endif

                    ForEach(vm.categoryAccuracy) { point in
                        HStack {
                            Text(point.category.shortName)
                            Spacer()
                            Text("\(Int((point.accuracy * 100).rounded()))%")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Questions par catégorie") {
                if vm.categoryCounts.allSatisfy({ $0.count == 0 }) {
                    Text("Aucune question chargée.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.categoryCounts) { item in
                        HStack {
                            Text(item.category.shortName)
                            Spacer()
                            Text("\(item.count)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Couverture par catégorie") {
                if vm.categoryCoverage.allSatisfy({ $0.total == 0 }) {
                    Text("Aucune question chargée.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.categoryCoverage) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(item.category.shortName, systemImage: item.category.systemImage)
                                Spacer()
                                Text("\(item.seen)/\(item.total)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: item.progress)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Couverture par sous-catégorie") {
                if vm.subcategoryCoverage.isEmpty {
                    Text("Aucune sous-catégorie chargée.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.subcategoryCoverage) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(item.category.shortName) • \(item.subcategory)")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(item.seen)/\(item.total)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: item.progress)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Progression par sous-catégorie (LOS)") {
                if vm.subcategoryProgress.isEmpty {
                    Text("Aucune donnée par sous-catégorie.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.subcategoryProgress) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.subcategory)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(item.attempted)/\(item.total)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: item.progress)
                            HStack {
                                Text("Précision")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int((item.accuracy * 100).rounded()))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
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

    private func formatTime(_ seconds: Double) -> String {
        guard seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func bindingForCategoryGoal(_ category: CFACategory) -> Binding<Int> {
        Binding(
            get: { vm.weeklyGoal(for: category) },
            set: { vm.setWeeklyGoal($0, for: category) }
        )
    }
}
