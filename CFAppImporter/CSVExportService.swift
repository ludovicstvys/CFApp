import Foundation

struct CSVExportService {
    static func exportQuestions(_ questions: [CFAQuestion]) -> String {
        let header = [
            "id", "level", "category", "subcategory", "stem",
            "choiceA", "choiceB", "choiceC", "choiceD", "choiceE", "choiceF",
            "answerIndex", "explanation", "difficulty", "image", "importedAt"
        ]
        let rows = questions.map { q in
            let choices = padChoices(q.choices, count: 6)
            return [
                q.id,
                String(q.level.rawValue),
                q.category.rawValue,
                q.subcategory ?? "",
                q.stem,
                choices[0],
                choices[1],
                choices[2],
                choices[3],
                choices[4],
                choices[5],
                formatAnswerIndices(q.correctIndices),
                q.explanation,
                q.difficulty.map(String.init) ?? "",
                q.imageName ?? "",
                q.importedAt.map(iso8601String) ?? ""
            ]
        }
        return buildCSV(header: header, rows: rows)
    }

    private static func padChoices(_ choices: [String], count: Int) -> [String] {
        if choices.count >= count { return Array(choices.prefix(count)) }
        return choices + Array(repeating: "", count: count - choices.count)
    }

    private static func formatAnswerIndices(_ indices: [Int]) -> String {
        let map = ["A", "B", "C", "D", "E", "F"]
        return indices.map { idx in
            if idx >= 0 && idx < map.count { return map[idx] }
            return String(idx)
        }.joined(separator: "|")
    }

    private static func buildCSV(header: [String], rows: [[String]]) -> String {
        var lines: [String] = []
        lines.append(header.map(escape).joined(separator: ","))
        for row in rows {
            lines.append(row.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        let needsQuotes = value.contains(",") || value.contains("\"") || value.contains("\n")
        var escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if needsQuotes {
            escaped = "\"\(escaped)\""
        }
        return escaped
    }

    private static func iso8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
