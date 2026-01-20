import Foundation

/// Import de questions depuis un CSV (offline).
/// - Sans dépendances tierces
/// - Gère guillemets, séparateurs (virgule / point-virgule), retours ligne dans champs quotés
///
/// Format recommandé (avec en-tête) :
/// id,level,category,subcategory,stem,choiceA,choiceB,choiceC,choiceD,answerIndex,explanation,difficulty
///
/// Formats sans en-tête supportés :
/// 1) Legacy (11 colonnes) :
///    id,level,category,stem,choiceA,choiceB,choiceC,choiceD,answerIndex,explanation,difficulty
/// 2) Nouveau (12 colonnes) :
///    id,level,category,subcategory,stem,choiceA,choiceB,choiceC,choiceD,answerIndex,explanation,difficulty
///
/// Notes :
/// - category : valeur libre (ex: "Ethics", "Éthique", "FRA", ou toute nouvelle catégorie)
/// - subcategory : texte libre (ex: "Time Value of Money")
/// - answerIndex :
///    - single : 0..3 ou A/B/C/D
///    - multi  : "0|2" ou "A|C" (séparateurs acceptés : | , ; espace)
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
            case .noRows: return "Aucune ligne exploitable dans le CSV."
            }
        }
    }

    func importQuestions(from data: Data) throws -> ImportResult {
        guard let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ImportError.emptyFile
        }

        let rows = parseCSV(string: string, delimiter: detectDelimiter(in: string))
            .filter { $0.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) }

        guard !rows.isEmpty else { throw ImportError.noRows }

        let headerCandidate = rows[0].map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        let hasHeader = headerCandidate.contains("stem") || headerCandidate.contains("question") || headerCandidate.contains("category")

        let header: [String: Int] = hasHeader ? headerIndexMap(headerCandidate) : [:]
        let startIndex = hasHeader ? 1 : 0

        var questions: [CFAQuestion] = []
        var errors: [String] = []
        var warnings: [String] = []

        for (i, row) in rows.enumerated() where i >= startIndex {
            do {
                let result = try parseQuestion(row: row, header: header)
                questions.append(result.question)
                warnings.append(contentsOf: result.warnings.map { "Ligne \(i + 1): \($0)" })
            } catch {
                errors.append("Ligne \(i + 1): \(error.localizedDescription)")
            }
        }

        if questions.isEmpty, !errors.isEmpty {
            throw NSError(domain: "CSVImport", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Import échoué. Exemple: \(errors[0])"
            ])
        }

        // Dédup by id (last wins)
        var dict: [String: CFAQuestion] = [:]
        for q in questions { dict[q.id] = q }
        questions = Array(dict.values)

        return ImportResult(questions: questions, errors: errors, warnings: warnings)
    }

    // MARK: - Parsing helpers

    private func detectDelimiter(in string: String) -> Character {
        let lines = string.split(whereSeparator: \.isNewline)
        guard let first = lines.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return ","
        }
        let line = String(first)
        let commaCount = line.filter { $0 == "," }.count
        let semiCount = line.filter { $0 == ";" }.count
        return semiCount > commaCount ? ";" : ","
    }

    private func headerIndexMap(_ header: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (idx, name) in header.enumerated() { map[name] = idx }
        return map
    }

    private func field(_ row: [String], header: [String: Int], keys: [String], fallbackIndex: Int?) -> String? {
        for k in keys {
            if let idx = header[k], idx < row.count { return row[idx] }
        }
        if let fallbackIndex, fallbackIndex < row.count { return row[fallbackIndex] }
        return nil
    }

    private func parseQuestion(row: [String], header: [String: Int]) throws -> (question: CFAQuestion, warnings: [String]) {
        var warnings: [String] = []
        let idRaw = field(row, header: header, keys: ["id", "qid", "question_id"], fallbackIndex: 0) ?? ""
        let id = idRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UUID().uuidString : idRaw.trimmingCharacters(in: .whitespacesAndNewlines)

        let levelStr = (field(row, header: header, keys: ["level", "cfa_level"], fallbackIndex: 1) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let levelInt = Int(levelStr), let level = CFALevel(rawValue: levelInt) else {
            throw NSError(domain: "CSVImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Champ 'level' invalide (attendu 1/2/3)."])
        }

        let categoryStr = (field(row, header: header, keys: ["category", "topic", "section"], fallbackIndex: 2) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let category = parseCategory(categoryStr) else {
            throw NSError(domain: "CSVImport", code: 3, userInfo: [NSLocalizedDescriptionKey: "Champ 'category' vide."])
        }

        // Indices (uniquement utiles si pas d'en-tête)
        let legacyNoHeader = header.isEmpty && row.count <= 11

        let subIdx: Int? = legacyNoHeader ? nil : 3
        let stemIdx = legacyNoHeader ? 3 : 4
        let aIdx = legacyNoHeader ? 4 : 5
        let bIdx = legacyNoHeader ? 5 : 6
        let cIdx = legacyNoHeader ? 6 : 7
        let dIdx = legacyNoHeader ? 7 : 8
        let ansIdx = legacyNoHeader ? 8 : 9
        let expIdx = legacyNoHeader ? 9 : 10
        let diffIdx = legacyNoHeader ? 10 : 11
        let imgIdx = legacyNoHeader ? nil : 12

        let subcategory = (field(row, header: header, keys: ["subcategory", "sub_category", "subtopic"], fallbackIndex: subIdx) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let subValue = subcategory.isEmpty ? nil : subcategory

        let stem = (field(row, header: header, keys: ["stem", "question", "prompt"], fallbackIndex: stemIdx) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stem.isEmpty else {
            throw NSError(domain: "CSVImport", code: 4, userInfo: [NSLocalizedDescriptionKey: "Champ 'stem' vide."])
        }

        let a = (field(row, header: header, keys: ["choicea", "choice_a", "a"], fallbackIndex: aIdx) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let b = (field(row, header: header, keys: ["choiceb", "choice_b", "b"], fallbackIndex: bIdx) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let c = (field(row, header: header, keys: ["choicec", "choice_c", "c"], fallbackIndex: cIdx) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let d = (field(row, header: header, keys: ["choiced", "choice_d", "d"], fallbackIndex: dIdx) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let choices = [a, b, c, d].filter { !$0.isEmpty }
        guard choices.count >= 2 else {
            throw NSError(domain: "CSVImport", code: 5, userInfo: [NSLocalizedDescriptionKey: "Choix insuffisants (au moins 2)."])
        }

        let ansRaw = (field(row, header: header, keys: ["answerindex", "answer_index", "answer", "correct"], fallbackIndex: ansIdx) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let correctIndices = parseAnswerIndices(ansRaw, choicesCount: choices.count)
        guard !correctIndices.isEmpty else {
            throw NSError(domain: "CSVImport", code: 6, userInfo: [NSLocalizedDescriptionKey: "answerIndex invalide (ex: 1 ou A|C)."])
        }

        let explanation = (field(row, header: header, keys: ["explanation", "rationale", "explication"], fallbackIndex: expIdx) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if explanation.isEmpty {
            warnings.append("explication manquante")
        }

        let diffStr = (field(row, header: header, keys: ["difficulty", "diff"], fallbackIndex: diffIdx) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let difficulty = Int(diffStr)
        if difficulty == nil, !diffStr.isEmpty {
            warnings.append("difficulty invalide (ignorée)")
        }

        let imageRaw = (field(row, header: header, keys: ["image", "photo", "image_name", "imagefilename"], fallbackIndex: imgIdx) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let imageName = imageRaw.isEmpty ? nil : imageRaw

        let question = CFAQuestion(
            id: id,
            level: level,
            category: category,
            subcategory: subValue,
            stem: stem,
            choices: choices,
            correctIndices: correctIndices.sorted(),
            explanation: explanation.isEmpty ? "—" : explanation,
            difficulty: difficulty,
            imageName: imageName,
            importedAt: Date()
        )
        return (question, warnings)
    }

    private func parseAnswerIndices(_ raw: String, choicesCount: Int) -> [Int] {
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }

        let separators = CharacterSet(charactersIn: "|,; ")
        let parts = raw
            .uppercased()
            .split(whereSeparator: { ch in
                String(ch).rangeOfCharacter(from: separators) != nil
            })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let map: [String: Int] = ["A": 0, "B": 1, "C": 2, "D": 3]
        var indices: [Int] = []

        for p in parts {
            if let i = Int(p), (0..<choicesCount).contains(i) {
                indices.append(i)
            } else if let i = map[p], (0..<choicesCount).contains(i) {
                indices.append(i)
            }
        }
        return Array(Set(indices)).sorted()
    }

    private func parseCategory(_ raw: String) -> CFACategory? {
        CFACategory.parse(raw)
    }

    private func parseCSV(string: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false

        let chars = Array(string)
        var i = 0

        while i < chars.count {
            let c = chars[i]

            if c == "\"" {
                if inQuotes {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if c == delimiter && !inQuotes {
                row.append(field); field = ""
            } else if (c == "\n" || c == "\r") && !inQuotes {
                if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                row.append(field); field = ""
                rows.append(row); row = []
            } else {
                field.append(c)
            }

            i += 1
        }

        row.append(field)
        rows.append(row)
        return rows
    }
}
