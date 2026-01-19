import Foundation
import SwiftUI
import Combine

@MainActor
final class QuizViewModel: ObservableObject {

    struct AnswerRecord: Identifiable, Hashable {
        let id: String
        let questionId: String
        let selectedIndices: [Int]      // vide = blanc
        let correctIndices: [Int]
        let category: CFACategory
        let subcategory: String?
        let stem: String
        let choices: [String]
        let explanation: String

        var isCorrect: Bool {
            Set(selectedIndices) == Set(correctIndices)
        }
    }

    enum State: Equatable {
        case idle
        case loading
        case running
        case finished
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    @Published private(set) var config: QuizConfig = .default()
    @Published private(set) var questions: [QuizEngine.PreparedQuestion] = []
    @Published private(set) var currentIndex: Int = 0

    /// Sélection en cours (support multi-réponses)
    @Published private(set) var selectedSet: Set<Int> = []
    /// Indique que la question courante a été soumise (révision : affiche feedback)
    @Published private(set) var isSubmitted: Bool = false

    @Published private(set) var records: [AnswerRecord] = []
    @Published private(set) var remainingSeconds: Int? = nil

    private let repo: QuestionRepository
    private let engine: QuizEngine
    private let sessionStore: QuizSessionStore
    private var timer: Timer?
    private var startedAt: Date?
    private var rng = SystemRandomNumberGenerator()

    init(
        repo: QuestionRepository = HybridQuestionRepository(),
        engine: QuizEngine = QuizEngine(),
        sessionStore: QuizSessionStore = .shared
    ) {
        self.repo = repo
        self.engine = engine
        self.sessionStore = sessionStore
    }

    var current: QuizEngine.PreparedQuestion? {
        guard currentIndex >= 0 && currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var isMultiAnswerCurrent: Bool {
        (current?.correctIndices.count ?? 0) > 1
    }

    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }

    var score: Int {
        records.filter { $0.isCorrect }.count
    }

    var total: Int { questions.count }

    func start(config: QuizConfig) {
        self.config = config
        state = .loading
        selectedSet = []
        isSubmitted = false
        currentIndex = 0
        records = []
        startedAt = Date()
        stopTimer()
        clearSession()

        do {
            let all = try repo.loadAllQuestions()
            let history = config.mode == .spaced ? QuestionHistoryStore.shared.loadAll() : [:]
            let prepared = engine.prepare(questions: all, config: config, historyById: history, rng: &rng)
            self.questions = prepared
            self.state = prepared.isEmpty ? .failed("Aucune question disponible pour ces filtres.") : .running

            if config.mode == .test, let limit = config.timeLimitSeconds {
                remainingSeconds = limit
                startTimer()
            } else {
                remainingSeconds = nil
            }

            if prepared.isEmpty {
                clearSession()
            } else {
                persistSession()
            }
        } catch {
            state = .failed(error.localizedDescription)
            clearSession()
        }
    }

    // MARK: - Selection

    func toggleSelection(_ index: Int) {
        guard state == .running else { return }

        // Si question déjà soumise en révision, on bloque (évite de changer après feedback)
        if config.mode == .revision, isSubmitted { return }

        // Single-answer : sélection directe (remplace) + soumission immédiate
        if !isMultiAnswerCurrent {
            selectedSet = [index]
            submitCurrent()
            return
        }

        // Multi-answer : toggle (check/uncheck)
        if selectedSet.contains(index) {
            selectedSet.remove(index)
        } else {
            selectedSet.insert(index)
        }
        persistSession()
    }

    func validate() {
        guard state == .running else { return }
        submitCurrent()
    }

    func skip() {
        guard state == .running else { return }
        selectedSet = []
        submitCurrent()
    }

    func goNext() {
        guard state == .running else { return }
        selectedSet = []
        isSubmitted = false

        if currentIndex + 1 < questions.count {
            currentIndex += 1
        } else {
            finish()
        }
        persistSession()
    }

    func finish() {
        guard state == .running else { return }
        stopTimer()
        state = .finished
        persistAttempt()
        clearSession()
    }

    func restart() {
        start(config: config)
    }

    // MARK: - Private

    private func submitCurrent() {
        guard let q = current else { return }
        // Evite double soumission en révision
        if config.mode == .revision, isSubmitted { return }

        appendRecord(for: q, selected: Array(selectedSet).sorted())

        if config.mode == .revision {
            isSubmitted = true
            persistSession()
        } else {
            // Mode test : on avance directement après validation/sélection
            goNext()
        }
    }

    private func appendRecord(for prepared: QuizEngine.PreparedQuestion, selected: [Int]) {
        let original = prepared.original
        let record = AnswerRecord(
            id: UUID().uuidString,
            questionId: original.id,
            selectedIndices: selected,
            correctIndices: prepared.correctIndices.sorted(),
            category: original.category,
            subcategory: original.subcategory,
            stem: prepared.stem,
            choices: prepared.choices,
            explanation: original.explanation
        )
        records.append(record)
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.state == .running else { return }
            guard let remaining = self.remainingSeconds else { return }

            if remaining <= 1 {
                self.remainingSeconds = 0
                self.recordCurrentIfNeeded()
                self.finish()
            } else {
                self.remainingSeconds = remaining - 1
                if remaining % 10 == 0 {
                    self.persistSession()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func recordCurrentIfNeeded() {
        guard let q = current else { return }
        if records.count > currentIndex { return }
        appendRecord(for: q, selected: Array(selectedSet).sorted())
    }

    func resumeIfAvailable() -> Bool {
        guard let session = sessionStore.load() else { return false }
        guard !session.questions.isEmpty else { return false }

        stopTimer()
        config = session.config
        questions = session.questions.map { stored in
            QuizEngine.PreparedQuestion(
                id: stored.id,
                original: stored.original,
                stem: stored.stem,
                choices: stored.choices,
                correctIndices: stored.correctIndices
            )
        }
        currentIndex = min(session.currentIndex, max(0, questions.count - 1))
        selectedSet = Set(session.selectedSet)
        isSubmitted = session.isSubmitted
        records = session.records.map { record in
            AnswerRecord(
                id: record.id,
                questionId: record.questionId,
                selectedIndices: record.selectedIndices,
                correctIndices: record.correctIndices,
                category: record.category,
                subcategory: record.subcategory,
                stem: record.stem,
                choices: record.choices,
                explanation: record.explanation
            )
        }
        remainingSeconds = session.remainingSeconds
        startedAt = session.startedAt ?? Date()
        state = .running

        if config.mode == .test, remainingSeconds != nil {
            startTimer()
        }

        return true
    }

    private func persistSession() {
        guard state == .running else { return }
        guard !questions.isEmpty else { return }

        let storedQuestions = questions.map { q in
            QuizSession.StoredPreparedQuestion(
                id: q.id,
                original: q.original,
                stem: q.stem,
                choices: q.choices,
                correctIndices: q.correctIndices
            )
        }

        let storedRecords = records.map { r in
            QuizSession.StoredAnswerRecord(
                id: r.id,
                questionId: r.questionId,
                selectedIndices: r.selectedIndices,
                correctIndices: r.correctIndices,
                category: r.category,
                subcategory: r.subcategory,
                stem: r.stem,
                choices: r.choices,
                explanation: r.explanation
            )
        }

        let session = QuizSession(
            config: config,
            questions: storedQuestions,
            currentIndex: currentIndex,
            selectedSet: Array(selectedSet).sorted(),
            isSubmitted: isSubmitted,
            records: storedRecords,
            remainingSeconds: remainingSeconds,
            startedAt: startedAt
        )
        sessionStore.save(session)
    }

    private func clearSession() {
        sessionStore.clear()
    }

    private func persistAttempt() {
        let duration = Int(Date().timeIntervalSince(startedAt ?? Date()))
        let categories = Array(Set(records.map { $0.category })).sorted { $0.rawValue < $1.rawValue }

        // Per category breakdown
        var perCat: [CFACategory: QuizAttempt.CategoryResult] = [:]
        for cat in Set(records.map { $0.category }) {
            let catRecords = records.filter { $0.category == cat }
            let correct = catRecords.filter { $0.isCorrect }.count
            perCat[cat] = .init(correct: correct, total: catRecords.count)
        }

        // Per subcategory breakdown (optionnel)
        var perSub: [String: QuizAttempt.CategoryResult] = [:]
        let subs = records.compactMap { $0.subcategory?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        for sub in Set(subs) {
            let subRecords = records.filter { ($0.subcategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == sub }
            perSub[sub] = .init(correct: subRecords.filter { $0.isCorrect }.count, total: subRecords.count)
        }

        let attempt = QuizAttempt(
            level: config.level,
            mode: config.mode,
            categories: categories,
            score: score,
            total: total,
            durationSeconds: duration,
            perCategory: perCat,
            perSubcategory: perSub.isEmpty ? nil : perSub
        )
        StatsStore.shared.saveAttempt(attempt)
        let results = records.map { QuestionHistoryStore.QuestionResult(questionId: $0.questionId, isCorrect: $0.isCorrect) }
        QuestionHistoryStore.shared.update(with: results, at: attempt.date)
    }
}
