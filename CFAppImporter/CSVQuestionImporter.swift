import Foundation

struct CSVQuestionImporter {

    struct ImportResult {
        let questions: [CFAQuestion]
        let errors: [String]
        let warnings: [String]
    }

    enum ImportError: Error, LocalizedError {
        case emptyFile
        case noRows

        var errorDescription: String? {
            switch self {
            case .emptyFile: return "Fichier CSV vide."
            case .noRows: return "Aucune ligne detectee dans le CSV."
            }
        }
    }

    func importQuestions(from data: Data) throws -> ImportResult {
        guard !data.isEmpty else { throw ImportError.emptyFile }

        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CSVImport", code: 0, userInfo: [NSLocalizedDescriptionKey: "CSV non UTF-8."])
        }

        let rows = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !rows.isEmpty else { throw ImportError.noRows }

        let headerCandidate = parseCSVRow(rows[0])
        let hasHeader = headerCandidate.contains("stem")
            || headerCandidate.contains("question")
            || headerCandidate.contains("category")

        var header: [String: Int] = [:]
        var startIndex = 0

        if hasHeader {
            for (idx, col) in headerCandidate.enumerated() {
                header[col.lowercased()] = idx
            }
            startIndex = 1
        }

        var questions: [CFAQuestion] = []
        var errors: [String] = []
        var warnings: [String] = []

        for (i, rawRow) in rows.enumerated() where i >= startIndex {
            let row = parseCSVRow(rawRow)
            do {
                let result = try parseQuestion(row: row, header: header)
                questions.append(result.question)
                warnings.append(contentsOf: result.warnings)
            } catch {
                errors.append("Ligne \(i + 1): \(error.localizedDescription)")
            }
        }

        if questions.isEmpty, !errors.isEmpty {
            throw NSError(domain: "CSVImport", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Import echoue. Exemple: \(errors[0])"
            ])
        }

        let deduped = QuestionDeduplicator.dedupe(questions)
        questions = deduped.questions
        if deduped.duplicates > 0 {
            warnings.append("Doublons ignores dans le CSV: \(deduped.duplicates)")
        }

        return ImportResult(questions: questions, errors: errors, warnings: warnings)
    }

    // MARK: - Parsing

    private func parseQuestion(row: [String], header: [String: Int]) throws -> (question: CFAQuestion, warnings: [String]) {
        let warnings: [String] = []

        _ = field(row, header: header, keys: ["id", "qid", "question_id"], fallbackIndex: 0)

        let levelRaw = field(row, header: header, keys: ["level"], fallbackIndex: 1) ?? ""
        guard let levelInt = Int(levelRaw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let level = CFALevel(rawValue: levelInt) else {
            throw NSError(domain: "CSVImport", code: 3, userInfo: [NSLocalizedDescriptionKey: "Champ 'level' invalide (attendu 1/2/3)."])
        }

        let catRaw = field(row, header: header, keys: ["category"], fallbackIndex: 2) ?? ""
        guard let category = parseCategory(catRaw) else {
            throw NSError(domain: "CSVImport", code: 4, userInfo: [NSLocalizedDescriptionKey: "Champ 'category' vide."])
        }

        let subcategory = field(row, header: header, keys: ["subcategory", "sub"], fallbackIndex: nil)
        let stemIdx = hasHeader(header) ? nil : 4
        let stem = (field(row, header: header, keys: ["stem", "question", "prompt"], fallbackIndex: stemIdx) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if stem.isEmpty {
            throw NSError(domain: "CSVImport", code: 5, userInfo: [NSLocalizedDescriptionKey: "Champ 'stem' vide."])
        }

        let choices = parseChoices(row: row, header: header)
        if choices.count < 2 {
            throw NSError(domain: "CSVImport", code: 6, userInfo: [NSLocalizedDescriptionKey: "Choix insuffisants (au moins 2)."])
        }

        let id = QuestionDeduplicator.stableId(stem: stem, choices: choices)

        let answerRaw = field(row, header: header, keys: ["answerindex", "answer", "correct"], fallbackIndex: 9) ?? ""
        let correctIndices = parseAnswerIndices(answerRaw, choicesCount: choices.count)
        if correctIndices.isEmpty {
            throw NSError(domain: "CSVImport", code: 7, userInfo: [NSLocalizedDescriptionKey: "answerIndex invalide (ex: 1 ou A|C)."])
        }

        let explanation = (field(row, header: header, keys: ["explanation", "justification"], fallbackIndex: 10) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let difficultyRaw = field(row, header: header, keys: ["difficulty", "diff"], fallbackIndex: 11)
        let difficulty = difficultyRaw.flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }

        let question = CFAQuestion(
            id: id,
            level: level,
            category: category,
            subcategory: subcategory,
            stem: stem,
            choices: choices,
            correctIndices: correctIndices,
            explanation: explanation,
            difficulty: difficulty,
            imageName: nil,
            importedAt: Date()
        )

        return (question, warnings)
    }

    private func parseCSVRow(_ row: String) -> [String] {
        var results: [String] = []
        var current = ""
        var insideQuotes = false

        for char in row {
            if char == "\"" {
                insideQuotes.toggle()
                continue
            }
            if char == "," && !insideQuotes {
                results.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        results.append(current)
        return results
    }

    private func field(_ row: [String], header: [String: Int], keys: [String], fallbackIndex: Int?) -> String? {
        for k in keys {
            if let idx = header[k.lowercased()], idx < row.count {
                return row[idx]
            }
        }
        if let idx = fallbackIndex, idx < row.count {
            return row[idx]
        }
        return nil
    }

    private func hasHeader(_ header: [String: Int]) -> Bool {
        !header.isEmpty
    }

    private func parseChoices(row: [String], header: [String: Int]) -> [String] {
        let keys = ["choicea", "choiceb", "choicec", "choiced", "choicee", "choicef"]
        var choices: [String] = []

        for (idx, key) in keys.enumerated() {
            let fallbackIndex = header.isEmpty ? (4 + idx) : nil
            if let val = field(row, header: header, keys: [key], fallbackIndex: fallbackIndex) {
                let trimmed = val.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    choices.append(trimmed)
                }
            }
        }
        return choices
    }

    private func parseAnswerIndices(_ raw: String, choicesCount: Int) -> [Int] {
        let cleaned = raw.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ";", with: "|")
            .replacingOccurrences(of: "/", with: "|")

        let parts = cleaned.split(separator: "|")
        var indices: [Int] = []

        for p in parts {
            if let idx = Int(p) {
                if idx >= 0 && idx < choicesCount { indices.append(idx) }
                continue
            }
            if let letter = p.first, letter >= "A", letter <= "F" {
                let idx = Int(letter.asciiValue! - Character("A").asciiValue!)
                if idx >= 0 && idx < choicesCount { indices.append(idx) }
            }
        }
        return Array(Set(indices)).sorted()
    }

    private func parseCategory(_ raw: String) -> CFACategory? {
        CFACategory.parse(raw)
    }
}
