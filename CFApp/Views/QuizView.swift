import SwiftUI

struct QuizView: View {
    enum StartMode {
        case new(config: QuizConfig)
        case resume(fallbackConfig: QuizConfig)
    }

    let startMode: StartMode
    @StateObject private var vm = QuizViewModel()
    @State private var reportQuestion: CFAQuestion? = nil
    @State private var showExplanationDetails = true
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
                ResultsView(
                    config: vm.config,
                    score: vm.score,
                    total: vm.total,
                    records: vm.records,
                    answeredCount: vm.answeredCount,
                    unansweredCount: vm.unansweredCount,
                    onRestart: { vm.restart() },
                    onDone: { }
                )
            }
        }
        .navigationTitle(vm.config.mode.title)
#if os(iOS) || os(tvOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            if vm.state == .running, let current = vm.current {
#if os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button {
                        reportQuestion = current.original
                    } label: {
                        Label("Signaler", systemImage: "exclamationmark.bubble")
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                    .accessibilityHint("Signaler un probleme sur la question courante")
                }
#else
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        reportQuestion = current.original
                    } label: {
                        Label("Signaler", systemImage: "exclamationmark.bubble")
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                    .accessibilityHint("Signaler un probleme sur la question courante")
                }
#endif
            }

            if vm.state == .running, vm.config.usesCountdown {
#if os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button {
                        vm.pauseSession()
                        dismiss()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .keyboardShortcut("p", modifiers: [.command])
                    .accessibilityHint("Met en pause puis revient a l'ecran precedent")
                }
#else
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        vm.pauseSession()
                        dismiss()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .keyboardShortcut("p", modifiers: [.command])
                    .accessibilityHint("Met en pause puis revient a l'ecran precedent")
                }
#endif
            }
        }
        .sheet(item: $reportQuestion) { question in
            ReportQuestionView(question: question)
        }
        .onAppear {
            switch startMode {
            case .new(let config):
                vm.start(config: config)
            case .resume(let fallbackConfig):
                if !vm.resumeIfAvailable() {
                    vm.start(config: fallbackConfig)
                }
            }
        }
        .onChange(of: vm.currentIndex) { _, _ in
            showExplanationDetails = true
        }
    }

    private var loading: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Chargement des questions...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func error(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
            Text("Impossible de demarrer le quiz")
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            PrimaryButton(title: "Reessayer", systemImage: "arrow.clockwise") {
                vm.start(config: vm.config)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var running: some View {
        Group {
            if let current = vm.current {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ProgressHeaderView(
                            label: "Question",
                            index: vm.currentIndex,
                            total: vm.total,
                            score: vm.score,
                            remainingSeconds: vm.remainingSeconds
                        )

                        QuestionCardView(
                            category: current.original.category,
                            subcategory: current.original.subcategory,
                            stem: current.stem,
                            imageName: current.original.imageName
                        )

                        if current.correctIndices.count > 1 {
                            Text("Plusieurs reponses possibles.")
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
                                        if vm.config.mode == .revision, vm.isSubmitted {
                                            return
                                        }
                                    }
                                )
                            }
                        }

                        if vm.config.mode == .revision, vm.isSubmitted {
                            explanationBlock(for: current)
                        }
                    }
                    .padding()
                    .padding(.bottom, AppButtonMetrics.minHeight + 34)
                }
                .safeAreaInset(edge: .bottom) {
                    actionBar(current: current)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        .background(.regularMaterial)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.snappy, value: vm.currentIndex)
    }

    private func actionBar(current: QuizEngine.PreparedQuestion) -> some View {
        let isMulti = current.correctIndices.count > 1
        let isTestLike = vm.config.mode == .test || vm.config.mode == .mock

        return HStack(spacing: 10) {
            Button {
                vm.skip()
            } label: {
                Label("Passer", systemImage: "forward.end.alt")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AppButtonMetrics.minHeight)
            }
            .appActionButton()
            .keyboardShortcut("s", modifiers: [])
            .accessibilityHint("Passe la question courante")

            if isMulti {
                Button {
                    if vm.config.mode == .revision, vm.isSubmitted {
                        vm.goNext()
                        return
                    }
                    vm.validate()
                    if vm.config.mode == .revision {
                        let correct = Set(vm.selectedSet) == Set(current.correctIndices)
                        correct ? Haptics.success() : Haptics.error()
                    }
                } label: {
                    Label(
                        isTestLike ? "Valider & Suivant" : (vm.isSubmitted ? "Suivant" : "Valider"),
                        systemImage: "checkmark"
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AppButtonMetrics.minHeight)
                }
                .appActionButton(prominent: true)
                .disabled(vm.config.mode == .revision && !vm.isSubmitted && vm.selectedSet.isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            } else {
                Button {
                    if vm.config.mode == .revision {
                        vm.goNext()
                    } else {
                        vm.validate()
                    }
                } label: {
                    Label(vm.currentIndex + 1 == vm.total ? "Terminer" : "Suivant", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AppButtonMetrics.minHeight)
                }
                .appActionButton(prominent: true)
                .disabled(vm.config.mode == .revision && !vm.isSubmitted && vm.selectedSet.isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
    }

    private func feedbackCorrectness(for idx: Int) -> Bool? {
        guard vm.config.mode == .revision, vm.isSubmitted, let current = vm.current else { return nil }
        if current.correctIndices.contains(idx) { return true }
        if vm.selectedSet.contains(idx) { return false }
        return nil
    }

    private func explanationBlock(for current: QuizEngine.PreparedQuestion) -> some View {
        let correct = Set(vm.selectedSet) == Set(current.correctIndices)
        let selectedSummary = answerSummary(for: Array(vm.selectedSet), in: current.choices)
        let expectedSummary = answerSummary(for: current.correctIndices, in: current.choices)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .foregroundStyle(correct ? .green : .red)
                Text(correct ? "Bonne reponse" : "Mauvaise reponse")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Ta reponse")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(selectedSummary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Bonne reponse")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(expectedSummary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DisclosureGroup("Explication detaillee", isExpanded: $showExplanationDetails) {
                Text(current.original.explanation)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func answerSummary(for indices: [Int], in choices: [String]) -> String {
        let lines = indices.sorted().compactMap { idx -> String? in
            guard choices.indices.contains(idx) else { return nil }
            let letter = UnicodeScalar(65 + idx).map { String($0) } ?? "?"
            return "\(letter). \(choices[idx])"
        }
        if lines.isEmpty {
            return "Aucune reponse selectionnee."
        }
        return lines.joined(separator: "\n")
    }
}
