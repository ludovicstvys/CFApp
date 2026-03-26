import Foundation
import SwiftUI
import Combine

@MainActor
final class QuizViewModel: ObservableObject {

    struct AnswerRecord: Identifiable, Hashable {
        let id: String
        let questionId: String
        let selectedIndices: [Int]
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
    @Published private(set) var selectedSet: Set<Int> = []
    @Published private(set) var isSubmitted: Bool = false
    @Published private(set) var records: [AnswerRecord] = []
    @Published private(set) var remainingSeconds: Int? = nil

    private let repo: QuestionRepository
    private let engine: QuizEngine
    private let sessionStore: QuizSessionStoring
    private let statsStore: StatsStoring
    private let historyStore: QuestionHistoryStoring
    private var timer: Timer?
    private var startedAt: Date?
    private var startGeneration = 0
    private var storedQuestionsForSession: [QuizSession.StoredPreparedQuestion] = []
    private var storedRecordsForSession: [QuizSession.StoredAnswerRecord] = []

    @MainActor
    convenience init() {
        self.init(
            repo: AppDependencies.shared.questionRepository,
            engine: QuizEngine(),
            sessionStore: AppDependencies.shared.sessionStore,
            statsStore: AppDependencies.shared.statsStore,
            historyStore: AppDependencies.shared.historyStore
        )
    }

    @MainActor
    init(
        repo: QuestionRepository,
        engine: QuizEngine,
        sessionStore: QuizSessionStoring,
        statsStore: StatsStoring,
        historyStore: QuestionHistoryStoring
    ) {
        self.repo = repo
        self.engine = engine
        self.sessionStore = sessionStore
        self.statsStore = statsStore
        self.historyStore = historyStore
    }

    deinit {
        timer?.invalidate()
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
    var answeredCount: Int { records.count }
    var unansweredCount: Int { max(0, total - answeredCount) }

    func start(config: QuizConfig) {
        self.config = config
        state = .loading
        selectedSet = []
        isSubmitted = false
        currentIndex = 0
        records = []
        storedQuestionsForSession = []
        storedRecordsForSession = []
        startedAt = Date()
        startGeneration += 1
        let generation = startGeneration
        stopTimer()
        clearSession()

        do {
            let all = try repo.loadAllQuestions()
            let history = config.mode == .spaced ? historyStore.loadAll() : [:]
            var rng = SystemRandomNumberGenerator()
            let prepared = engine.prepare(questions: all, config: config, historyById: history, rng: &rng)

            guard startGeneration == generation else { return }

            questions = prepared
            storedQuestionsForSession = prepared.map { q in
                QuizSession.StoredPreparedQuestion(
                    id: q.id,
                    original: q.original,
                    stem: q.stem,
                    choices: q.choices,
                    correctIndices: q.correctIndices
                )
            }
            state = prepared.isEmpty ? .failed("Aucune question disponible pour ces filtres.") : .running

            if config.usesCountdown, let limit = config.effectiveTimeLimitSeconds {
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
            guard startGeneration == generation else { return }
            state = .failed(error.localizedDescription)
            clearSession()
        }
    }

    // MARK: - Selection

    func toggleSelection(_ index: Int) {
        guard state == .running else { return }
        if config.mode == .revision, isSubmitted { return }

        if !isMultiAnswerCurrent {
            selectedSet = [index]
            submitCurrent()
            return
        }

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

    func pauseSession() {
        guard state == .running else { return }
        stopTimer()
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
        if config.mode == .revision, isSubmitted { return }

        appendRecord(for: q, selected: Array(selectedSet).sorted())

        if config.mode == .revision {
            isSubmitted = true
            persistSession()
        } else {
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
        storedRecordsForSession.append(
            QuizSession.StoredAnswerRecord(
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
        )
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
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
        storedQuestionsForSession = session.questions
        storedRecordsForSession = session.records
        remainingSeconds = session.remainingSeconds
        startedAt = session.startedAt ?? Date()
        state = .running

        if config.usesCountdown, remainingSeconds != nil {
            startTimer()
        }

        return true
    }

    private func persistSession() {
        guard state == .running else { return }
        guard !questions.isEmpty else { return }

        let session = QuizSession(
            config: config,
            questions: storedQuestionsForSession,
            currentIndex: currentIndex,
            selectedSet: Array(selectedSet).sorted(),
            isSubmitted: isSubmitted,
            records: storedRecordsForSession,
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

        var perCat: [CFACategory: QuizAttempt.CategoryResult] = [:]
        for cat in Set(records.map { $0.category }) {
            let catRecords = records.filter { $0.category == cat }
            let correct = catRecords.filter { $0.isCorrect }.count
            perCat[cat] = .init(correct: correct, total: catRecords.count)
        }

        var perSub: [String: QuizAttempt.CategoryResult] = [:]
        let subs = records
            .compactMap { $0.subcategory?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
        statsStore.saveAttempt(attempt)
        let results = records.map { QuestionHistoryStore.QuestionResult(questionId: $0.questionId, isCorrect: $0.isCorrect) }
        historyStore.update(with: results, at: attempt.date)
    }
}
