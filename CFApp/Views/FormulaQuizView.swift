import SwiftUI

struct FormulaQuizView: View {
    let config: QuizConfig
    @StateObject private var vm = FormulaQuizViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading:
                loading
            case .failed(let message):
                error(message)
            case .running:
                running
            case .finished:
                finished
            }
        }
        .navigationTitle("Formules")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.start(config: config)
        }
    }

    private var loading: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Chargement des formules…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func error(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
            Text("Impossible de démarrer le quiz")
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            PrimaryButton(title: "Réessayer", systemImage: "arrow.clockwise") {
                vm.start(config: config)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var running: some View {
        VStack(alignment: .leading, spacing: 14) {
            ProgressHeaderView(
                label: "Formule",
                index: vm.currentIndex,
                total: vm.total,
                score: vm.score,
                remainingSeconds: nil
            )

            if let current = vm.current {
                FormulaCardView(
                    category: current.category,
                    topic: current.topic,
                    title: current.title,
                    formula: vm.revealed ? current.formula : nil,
                    notes: vm.revealed ? current.notes : nil,
                    imageName: vm.revealed ? current.imageName : nil
                )

                if !vm.revealed {
                    PrimaryButton(title: "Afficher la formule", systemImage: "eye") {
                        vm.reveal()
                    }
                } else {
                    Text("Auto-vérif : compare et choisis ta réponse.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button {
                            vm.markKnown()
                        } label: {
                            Label("Je savais", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            vm.markUnknown()
                        } label: {
                            Label("À revoir", systemImage: "arrow.uturn.left")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Button {
                    vm.skip()
                } label: {
                    Label("Passer", systemImage: "forward.end.alt")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .animation(.snappy, value: vm.currentIndex)
    }

    private var finished: some View {
        let incorrect = vm.records.filter { !$0.isCorrect }

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terminé ✅")
                    .font(.largeTitle.bold())

                StatPillView(title: "Score", value: "\(vm.score)/\(vm.total)", systemImage: "checkmark.circle.fill")

                if incorrect.isEmpty {
                    Text("Aucune formule à revoir.")
                        .foregroundStyle(.secondary)
                } else {
                    GroupBox("Formules à revoir") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(incorrect) { record in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.title)
                                        .font(.subheadline.weight(.semibold))
                                    if let topic = record.topic, !topic.isEmpty {
                                        Text(topic)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Text("Les formules non sues ont été ajoutées aux favoris.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    PrimaryButton(title: "Recommencer", systemImage: "arrow.clockwise") {
                        vm.restart()
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
            .padding()
        }
    }
}
