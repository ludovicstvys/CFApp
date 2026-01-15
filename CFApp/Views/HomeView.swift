import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @State private var startQuiz = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

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
                        .pickerStyle(.segmented)
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
                }

                GroupBox("Catégories") {
                    CategoryPickerView(
                        selected: $vm.selectedCategories,
                        onToggle: vm.toggleCategory(_:),
                        onSelectAll: vm.selectAllCategories,
                        onClear: vm.clearCategories
                    )
                }

                GroupBox("Sous-catégories (optionnel)") {
                    SubcategoryPickerView(
                        available: vm.availableSubcategories,
                        selected: $vm.selectedSubcategories,
                        onToggle: vm.toggleSubcategory(_:),
                        onSelectAll: vm.selectAllSubcategories,
                        onClear: vm.clearSubcategories
                    )
                }

                GroupBox("Paramètres du quiz") {
                    VStack(alignment: .leading, spacing: 12) {
                        Stepper("Nombre de questions : \(vm.numberOfQuestions)", value: $vm.numberOfQuestions, in: 5...60, step: 5)

                        Toggle("Mélanger les réponses", isOn: $vm.shuffleAnswers)

                        if vm.mode == .test {
                            Stepper("Limite de temps (minutes) : \(vm.timeLimitMinutes)", value: $vm.timeLimitMinutes, in: 0...180, step: 5)
                            Text("0 = pas de limite de temps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("En mode Révision, le feedback est immédiat. En mode Test, le feedback est à la fin.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                PrimaryButton(title: "Démarrer", systemImage: "play.fill") {
                    startQuiz = true
                }
                .padding(.top, 6)
            }
            .padding()
        }
        .navigationTitle("CFA Quiz")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $startQuiz) {
            QuizView(config: vm.config)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Révise efficacement le CFA")
                .font(.title.bold())

            Text("Offline, modular, et prêt pour évoluer vers un backend (scores, profils, stats).")
                .foregroundStyle(.secondary)
        }
    }
}
