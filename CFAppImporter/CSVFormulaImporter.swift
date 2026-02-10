import Foundation

struct CSVFormulaImporter {
    struct ImportResult {
        let formulas: [CFAFormula]
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

    func importFormulas(from data: Data, delimiter: Character = ",") throws -> ImportResult {
        guard !data.isEmpty else { throw ImportError.emptyFile }

        guard let text = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CSVImport", code: 0, userInfo: [NSLocalizedDescriptionKey: "CSV non UTF-8."])
        }

        let rows = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !rows.isEmpty else { throw ImportError.noRows }

        let headerCandidate = parseCSVRow(rows[0], delimiter: delimiter)
        let normalizedHeader = headerCandidate.map { $0.lowercased() }
        let hasHeader = normalizedHeader.contains("formula")
            || normalizedHeader.contains("title")
            || normalizedHeader.contains("category")

        var header: [String: Int] = [:]
        var startIndex = 0

        if hasHeader {
            for (idx, col) in normalizedHeader.enumerated() {
                header[col] = idx
            }
            startIndex = 1
        }

        var formulas: [CFAFormula] = []
        var errors: [String] = []
        var warnings: [String] = []

        for (i, rawRow) in rows.enumerated() where i >= startIndex {
            let row = parseCSVRow(rawRow, delimiter: delimiter)
            do {
                let result = try parseFormula(row: row, header: header)
                formulas.append(result.formula)
                warnings.append(contentsOf: result.warnings)
            } catch {
                errors.append("Ligne \(i + 1): \(error.localizedDescription)")
            }
        }

        if formulas.isEmpty, !errors.isEmpty {
            throw NSError(domain: "CSVImport", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Import echoue. Exemple: \(errors[0])"
            ])
        }

        let deduped = FormulaDeduplicator.dedupe(formulas)
        formulas = deduped.formulas
        if deduped.duplicates > 0 {
            warnings.append("Doublons ignores dans le CSV: \(deduped.duplicates)")
        }

        return ImportResult(formulas: formulas, errors: errors, warnings: warnings)
    }

    private func parseFormula(row: [String], header: [String: Int]) throws -> (formula: CFAFormula, warnings: [String]) {
        let warnings: [String] = []

        let catRaw = field(row, header: header, keys: ["category"], fallbackIndex: 0) ?? ""
        guard let category = CFACategory.parse(catRaw) else {
            throw NSError(domain: "CSVImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Champ 'category' vide."])
        }

        let topic = field(row, header: header, keys: ["topic", "subcategory", "sub"], fallbackIndex: 1)

        let title = (field(row, header: header, keys: ["title", "name"], fallbackIndex: 2) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            throw NSError(domain: "CSVImport", code: 3, userInfo: [NSLocalizedDescriptionKey: "Champ 'title' vide."])
        }

        let formulaText = (field(row, header: header, keys: ["formula", "equation"], fallbackIndex: 3) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if formulaText.isEmpty {
            throw NSError(domain: "CSVImport", code: 4, userInfo: [NSLocalizedDescriptionKey: "Champ 'formula' vide."])
        }

        let notes = field(row, header: header, keys: ["notes", "note", "comment"], fallbackIndex: 4)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let imageName = field(row, header: header, keys: ["image", "imagename", "image_name"], fallbackIndex: 5)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let questionIdsRaw = field(
            row,
            header: header,
            keys: ["question_ids", "questionids", "question_id", "questions"],
            fallbackIndex: 6
        )
        let questionIds = parseList(questionIdsRaw)

        let formula = CFAFormula(
            id: UUID().uuidString,
            category: category,
            topic: topic?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : topic?.trimmingCharacters(in: .whitespacesAndNewlines),
            title: title,
            formula: formulaText,
            notes: notes?.isEmpty == true ? nil : notes,
            imageName: imageName?.isEmpty == true ? nil : imageName,
            questionIds: questionIds.isEmpty ? nil : questionIds,
            importedAt: Date()
        )

        return (formula, warnings)
    }

    private func parseCSVRow(_ row: String, delimiter: Character) -> [String] {
        var results: [String] = []
        var current = ""
        var insideQuotes = false

        for char in row {
            if char == "\"" {
                insideQuotes.toggle()
                continue
            }
            if char == delimiter && !insideQuotes {
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

    private func parseList(_ raw: String?) -> [String] {
        guard let raw else { return [] }
        let cleaned = raw
            .replacingOccurrences(of: ";", with: "|")
            .replacingOccurrences(of: "/", with: "|")
        return cleaned
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
