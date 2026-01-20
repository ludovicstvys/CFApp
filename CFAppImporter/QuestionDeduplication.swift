import Foundation

extension CFAQuestion {
    var dedupeKey: String {
        let parts = [stem] + Array(choices.prefix(4))
        return parts.map { Self.normalizeDedupeValue($0) }.joined(separator: "|")
    }

    fileprivate static func normalizeDedupeValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let collapsed = trimmed.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsed
    }
}

struct QuestionDeduplicator {
    static func dedupeKey(stem: String, choices: [String]) -> String {
        let parts = [stem] + Array(choices.prefix(4))
        return parts.map { CFAQuestion.normalizeDedupeValue($0) }.joined(separator: "|")
    }

    static func stableId(stem: String, choices: [String]) -> String {
        stableId(for: dedupeKey(stem: stem, choices: choices))
    }

    static func stableId(for key: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(format: "q_%016llx", hash)
    }

    static func dedupe(_ questions: [CFAQuestion]) -> (questions: [CFAQuestion], duplicates: Int) {
        var seen = Set<String>()
        var result: [CFAQuestion] = []
        var duplicates = 0

        for question in questions {
            let key = question.dedupeKey
            if seen.contains(key) {
                duplicates += 1
                continue
            }
            seen.insert(key)
            result.append(question)
        }

        return (result, duplicates)
    }

    static func merge(existing: [CFAQuestion], incoming: [CFAQuestion]) -> (questions: [CFAQuestion], duplicates: Int) {
        var seen = Set<String>()
        var result: [CFAQuestion] = []
        var duplicates = 0

        for question in existing {
            let key = question.dedupeKey
            if seen.contains(key) {
                duplicates += 1
                continue
            }
            seen.insert(key)
            result.append(question)
        }

        for question in incoming {
            let key = question.dedupeKey
            if seen.contains(key) {
                duplicates += 1
                continue
            }
            seen.insert(key)
            result.append(question)
        }

        return (result, duplicates)
    }
}
