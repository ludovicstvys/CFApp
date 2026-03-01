import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @State private var startQuiz = false
    @State private var resumeQuiz = false
    @State private var startFormulaQuiz = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let summary = vm.savedSessionSummary {
                    GroupBox("Reprendre une session") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(summary.config.mode.title) • \(summary.config.level.title)")
                                .font(.subheadline.weight(.semibold))
                            Text("Progression : \(min(summary.currentIndex + 1, summary.total))/\(summary.total)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            PrimaryButton(title: "Reprendre", systemImage: "arrow.uturn.right") {
                                resumeQuiz = true
                            }

                            Button(role: .destructive) {
                                vm.clearSavedSession()
                            } label: {
                                Text("Supprimer la session")
                                    .frame(maxWidth: .infinity)
                            }
                            .appActionButton()
                        }
                    }
                }

                GroupBox("Mode") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Mode", selection: $vm.mode) {
                            ForEach(QuizMode.allCases) { mode in
                                VStack(alignment: .leading) {
                                    Text(mode.title)
                                    Text(mode.description).font(.caption).foregroundStyle(.secondary)
                                }
                                .tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                GroupBox("Niveau") {
                    Picker("Niveau", selection: $vm.level) {
                        ForEach(CFALevel.allCases) { lvl in
                            Text(lvl.title).tag(lvl)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: vm.level) { _ in
                        vm.onLevelChanged()
                    }
                    .disabled(vm.mode == .formulas)

                    if vm.mode == .formulas {
                        Text("Le niveau ne s'applique pas au mode Formules.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                GroupBox("Categories") {
                    CategoryPickerView(
                        categories: vm.availableCategories,
                        selected: $vm.selectedCategories,
                        onToggle: vm.toggleCategory(_:),
                        onSelectAll: vm.selectAllCategories,
                        onClear: vm.clearCategories
                    )
                    .disabled(vm.mode == .random)

                    if vm.mode == .random {
                        Text("En mode Aleatoire, les categories sont ignorees.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                GroupBox(vm.mode == .formulas ? "Topics (optionnel)" : "Sous-categories (optionnel)") {
                    SubcategoryPickerView(
                        available: vm.availableSubcategories,
                        selected: $vm.selectedSubcategories,
                        onToggle: vm.toggleSubcategory(_:),
                        onSelectAll: vm.selectAllSubcategories,
                        onClear: vm.clearSubcategories
                    )
                    .disabled(vm.mode == .random)

                    if vm.mode == .random {
                        Text("En mode Aleatoire, les sous-categories sont ignorees.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if vm.mode == .formulas {
                        Text("Les topics filtrent les formules du quiz.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                GroupBox("Parametres du quiz") {
                    VStack(alignment: .leading, spacing: 12) {
                        Stepper("Nombre de questions : \(vm.numberOfQuestions)", value: $vm.numberOfQuestions, in: 5...120, step: 5)

                        if vm.mode != .formulas {
                            Toggle("Melanger les reponses", isOn: $vm.shuffleAnswers)

                            if vm.mode == .test {
                                Stepper("Limite de temps (minutes) : \(vm.timeLimitMinutes)", value: $vm.timeLimitMinutes, in: 0...180, step: 5)
                                Text("0 = pas de limite de temps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if vm.mode == .mock {
                                Stepper("Duree mock (minutes) : \(vm.mockExamMinutes)", value: $vm.mockExamMinutes, in: 30...360, step: 15)
                                Text("Le mode mock supporte pause/reprise entre sessions.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("En mode Revision, le feedback est immediat. En mode Test/Mock, le feedback est a la fin.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Quiz de formules avec auto-verification.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                PrimaryButton(title: String(localized: "app.quiz.start", defaultValue: "Demarrer"), systemImage: "play.fill") {
                    if vm.mode == .formulas {
                        startFormulaQuiz = true
                    } else {
                        startQuiz = true
                    }
                }
                .padding(.top, 6)
                .accessibilityHint("Lance un nouveau quiz avec les filtres choisis")
            }
            .padding()
        }
        .navigationTitle("CFA Quiz")
#if os(iOS) || os(tvOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .navigationDestination(isPresented: $startQuiz) {
            QuizView(startMode: .new(config: vm.config))
        }
        .navigationDestination(isPresented: $startFormulaQuiz) {
            FormulaQuizView(config: vm.config)
        }
        .navigationDestination(isPresented: $resumeQuiz) {
            QuizView(startMode: .resume(fallbackConfig: vm.config))
        }
        .onAppear { vm.refreshSavedSession() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "app.home.title", defaultValue: "Revise efficacement le CFA"))
                .font(.title.bold())

            Text("Offline, modulaire, et pret pour evoluer vers un backend (scores, profils, stats).")
                .foregroundStyle(.secondary)
        }
    }
}
