//
//  CFAppTests.swift
//  CFAppTests
//
//  Created by Ludovic Saint-Yves on 15/01/2026.
//

import XCTest
@testable import CFApp

final class CFAppTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testQuizEngineFiltersAndRandomMode() throws {
        let questions = [
            CFAQuestion(
                id: "q1",
                level: .level1,
                category: .ethics,
                stem: "Q1",
                choices: ["A", "B"],
                correctIndices: [0],
                explanation: "E1"
            ),
            CFAQuestion(
                id: "q2",
                level: .level1,
                category: .quantitativeMethods,
                stem: "Q2",
                choices: ["A", "B"],
                correctIndices: [1],
                explanation: "E2"
            ),
            CFAQuestion(
                id: "q3",
                level: .level2,
                category: .ethics,
                stem: "Q3",
                choices: ["A", "B"],
                correctIndices: [0],
                explanation: "E3"
            )
        ]

        let engine = QuizEngine()
        var rng = SystemRandomNumberGenerator()

        let configFiltered = QuizConfig(
            level: .level1,
            mode: .revision,
            categories: [.ethics],
            subcategories: [],
            numberOfQuestions: 10,
            shuffleAnswers: false,
            timeLimitSeconds: nil
        )
        let filtered = engine.prepare(questions: questions, config: configFiltered, rng: &rng)
        XCTAssertEqual(Set(filtered.map { $0.id }), Set(["q1"]))

        let configRandom = QuizConfig(
            level: .level1,
            mode: .random,
            categories: [.ethics],
            subcategories: [],
            numberOfQuestions: 10,
            shuffleAnswers: false,
            timeLimitSeconds: nil
        )
        let random = engine.prepare(questions: questions, config: configRandom, rng: &rng)
        XCTAssertEqual(Set(random.map { $0.id }), Set(["q1", "q2"]))
    }

    func testQuizEngineRejectsInvalidQuestions() throws {
        let questions = [
            CFAQuestion(
                id: "q1",
                level: .level1,
                category: .ethics,
                stem: "Q1",
                choices: ["A"],
                correctIndices: [0],
                explanation: "E1"
            ),
            CFAQuestion(
                id: "q2",
                level: .level1,
                category: .ethics,
                stem: "Q2",
                choices: ["A", "B"],
                correctIndices: [3],
                explanation: "E2"
            ),
            CFAQuestion(
                id: "q3",
                level: .level1,
                category: .ethics,
                stem: "Q3",
                choices: ["A", "B"],
                correctIndices: [0],
                explanation: "E3"
            )
        ]

        let engine = QuizEngine()
        var rng = SystemRandomNumberGenerator()
        let config = QuizConfig(
            level: .level1,
            mode: .revision,
            categories: [.ethics],
            subcategories: [],
            numberOfQuestions: 10,
            shuffleAnswers: false,
            timeLimitSeconds: nil
        )
        let prepared = engine.prepare(questions: questions, config: config, rng: &rng)
        XCTAssertEqual(prepared.count, 1)
        XCTAssertEqual(prepared.first?.id, "q3")
    }

    func testCSVImportWarningsAndParsing() throws {
        let csv = """
        id,level,category,subcategory,stem,choiceA,choiceB,choiceC,choiceD,answerIndex,explanation,difficulty
        q1,1,Ethics,,Question?,A,B,C,D,A,,x
        """
        let data = csv.data(using: .utf8) ?? Data()
        let importer = CSVQuestionImporter()
        let result = try importer.importQuestions(from: data)

        XCTAssertEqual(result.questions.count, 1)
        XCTAssertFalse(result.warnings.isEmpty)
    }

    func testStatsStoreSaveAndLoad() throws {
        let defaults = UserDefaults.standard
        let key = "cfaquiz.attempts.v1"
        let previous = defaults.data(forKey: key)
        defer {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        StatsStore.shared.clear()
        let attempt = QuizAttempt(
            level: .level1,
            mode: .revision,
            categories: [.ethics],
            score: 1,
            total: 2,
            durationSeconds: 30,
            perCategory: [.ethics: .init(correct: 1, total: 2)]
        )
        StatsStore.shared.saveAttempt(attempt)
        let attempts = StatsStore.shared.loadAttempts()
        XCTAssertEqual(attempts.first?.id, attempt.id)
    }

}
