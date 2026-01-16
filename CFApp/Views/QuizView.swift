import SwiftUI

struct QuizView: View {
    let config: QuizConfig
    @StateObject private var vm = QuizViewModel()

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
                ResultsView(
                    config: config,
                    score: vm.score,
                    total: vm.total,
                    records: vm.records,
                    onRestart: { vm.restart() },
                    onDone: { /* pop via nav */ }
                )
            }
        }
        .navigationTitle(config.mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.start(config: config) }
    }

    private var loading: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Chargement des questions…")
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
                index: vm.currentIndex,
                total: vm.total,
                score: vm.score,
                remainingSeconds: vm.remainingSeconds
            )

            if let current = vm.current {
                QuestionCardView(
                    category: current.original.category,
                    subcategory: current.original.subcategory,
                    stem: current.stem
                )

                if current.correctIndices.count > 1 {
                    Text("Plusieurs réponses possibles.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach(Array(current.choices.enumerated()), id: \.offset) { idx, choice in
                        ChoiceRowView(
                            text: choice,
                            isSelected: vm.selectedSet.contains(idx),
                            isCorrect: feedbackCorrectness(for: idx),
                            isMultiSelect: current.correctIndices.count > 1,
                            onTap: {
                                vm.toggleSelection(idx)
                                if config.mode == .revision, vm.isSubmitted {
                                    // pas de haptics si déjà soumis
                                    return
                                }
                            }
                        )
                    }
                }

                if config.mode == .revision, vm.isSubmitted {
                    explanationBlock(for: current)
                }

                Spacer(minLength: 0)

                actionBar(current: current)
            }

        }
        .padding()
        .animation(.snappy, value: vm.currentIndex)
    }

    private func actionBar(current: QuizEngine.PreparedQuestion) -> some View {
        let isMulti = current.correctIndices.count > 1

        return HStack(spacing: 10) {
            Button {
                vm.skip()
            } label: {
                Label("Passer", systemImage: "forward.end.alt")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if isMulti {
                Button {
                    if config.mode == .revision, vm.isSubmitted {
                        vm.goNext()
                        return
                    }
                    vm.validate()
                    if config.mode == .revision {
                        let correct = Set(vm.selectedSet) == Set(current.correctIndices)
                        correct ? Haptics.success() : Haptics.error()
                    }
                } label: {
                    Label(config.mode == .test ? "Valider & Suivant" : (vm.isSubmitted ? "Suivant" : "Valider"), systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(config.mode == .revision && !vm.isSubmitted && vm.selectedSet.isEmpty)
            } else {
                Button {
                    if config.mode == .revision {
                        vm.goNext()
                    } else {
                        vm.validate()
                    }
                } label: {
                    Label(vm.currentIndex + 1 == vm.total ? "Terminer" : "Suivant", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(config.mode == .revision && !vm.isSubmitted && vm.selectedSet.isEmpty)
            }
        }
    }

    private func feedbackCorrectness(for idx: Int) -> Bool? {
        guard config.mode == .revision, vm.isSubmitted, let current = vm.current else { return nil }
        if current.correctIndices.contains(idx) { return true }
        if vm.selectedSet.contains(idx) { return false }
        return nil
    }

    private func explanationBlock(for current: QuizEngine.PreparedQuestion) -> some View {
        let correct = Set(vm.selectedSet) == Set(current.correctIndices)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .foregroundStyle(correct ? .green : .red)
                Text(correct ? "Bonne réponse" : "Mauvaise réponse")
                    .font(.headline)
            }

            Text(current.original.explanation)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
