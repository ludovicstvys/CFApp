import Foundation

extension CFAFormula {
    var dedupeKey: String {
        let parts = [
            category.rawValue,
            topic ?? "",
            title,
            formula
        ]
        return parts.map { Self.normalizeDedupeValue($0) }.joined(separator: "|")
    }

    private static func normalizeDedupeValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let collapsed = trimmed.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsed
    }
}

struct FormulaDeduplicator {
    static func dedupe(_ formulas: [CFAFormula]) -> (formulas: [CFAFormula], duplicates: Int) {
        var seen = Set<String>()
        var result: [CFAFormula] = []
        var duplicates = 0

        for formula in formulas {
            let key = formula.dedupeKey
            if seen.contains(key) {
                duplicates += 1
                continue
            }
            seen.insert(key)
            result.append(formula)
        }

        return (result, duplicates)
    }

    static func merge(existing: [CFAFormula], incoming: [CFAFormula]) -> (formulas: [CFAFormula], duplicates: Int) {
        var seen = Set<String>()
        var result: [CFAFormula] = []
        var duplicates = 0

        for formula in existing {
            let key = formula.dedupeKey
            if seen.contains(key) {
                duplicates += 1
                continue
            }
            seen.insert(key)
            result.append(formula)
        }

        for formula in incoming {
            let key = formula.dedupeKey
            if seen.contains(key) {
                duplicates += 1
                continue
            }
            seen.insert(key)
            result.append(formula)
        }

        return (result, duplicates)
    }
}
