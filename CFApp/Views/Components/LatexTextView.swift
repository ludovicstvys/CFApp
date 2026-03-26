import SwiftUI

struct LatexTextView: View {
    let content: String
    var isBlock: Bool = true

    var body: some View {
        Text(OfflineLatexRenderer.render(content))
            .font(.system(.body, design: .serif))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, isBlock ? 2 : 0)
    }
}

private enum OfflineLatexRenderer {
    static func render(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        text = stripDelimiters(in: text)
        text = replaceFractions(in: text)
        text = replaceRoots(in: text)
        text = replaceCommands(in: text)
        text = applySuperAndSubscripts(in: text)
        text = cleanup(text)

        return text
    }

    private static func stripDelimiters(in input: String) -> String {
        var output = input
        let delimiters = ["$$", "$", "\\[", "\\]", "\\(", "\\)"]
        for delimiter in delimiters {
            output = output.replacingOccurrences(of: delimiter, with: "")
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replaceFractions(in input: String) -> String {
        transformCommands(in: input, command: "\\frac", arity: 2) { args in
            let num = render(args[0])
            let den = render(args[1])
            return "(\(num))/(\(den))"
        }
    }

    private static func replaceRoots(in input: String) -> String {
        transformCommands(in: input, command: "\\sqrt", arity: 1) { args in
            "√(\(render(args[0])))"
        }
    }

    private static func transformCommands(
        in input: String,
        command: String,
        arity: Int,
        transform: ([String]) -> String
    ) -> String {
        let chars = Array(input)
        var index = 0
        var output = ""

        while index < chars.count {
            if hasPrefix(chars, index: index, prefix: Array(command)) {
                var cursor = index + command.count
                var args: [String] = []
                var success = true

                for _ in 0..<arity {
                    skipSpaces(chars, index: &cursor)
                    guard let arg = extractArgument(chars, index: &cursor) else {
                        success = false
                        break
                    }
                    args.append(arg)
                }

                if success {
                    output += transform(args)
                    index = cursor
                    continue
                }
            }

            output.append(chars[index])
            index += 1
        }

        return output
    }

    private static func replaceCommands(in input: String) -> String {
        let chars = Array(input)
        var index = 0
        var output = ""

        while index < chars.count {
            let current = chars[index]
            if current == "\\" {
                let next = index + 1
                if next < chars.count, chars[next].isLetter {
                    var end = next
                    while end < chars.count, chars[end].isLetter {
                        end += 1
                    }
                    let command = String(chars[next..<end])
                    if let replacement = commandReplacements[command] {
                        output += replacement
                    } else if command == "left" || command == "right" || command == "text" {
                        // Ignore layout-only commands.
                    } else {
                        output += command
                    }
                    index = end
                    continue
                } else if next < chars.count {
                    output.append(chars[next])
                    index += 2
                    continue
                }
            }

            output.append(current)
            index += 1
        }

        return output
    }

    private static func applySuperAndSubscripts(in input: String) -> String {
        let chars = Array(input)
        var index = 0
        var output = ""

        while index < chars.count {
            let current = chars[index]
            if current == "^" || current == "_" {
                let isSuperscript = current == "^"
                var cursor = index + 1
                guard let token = extractArgument(chars, index: &cursor) else {
                    output.append(current)
                    index += 1
                    continue
                }

                let mapped = mapScript(token: token, superscript: isSuperscript)
                output += mapped
                index = cursor
                continue
            }

            if current != "{" && current != "}" {
                output.append(current)
            }
            index += 1
        }

        return output
    }

    private static func mapScript(token: String, superscript: Bool) -> String {
        let mapping = superscript ? superscriptMap : subscriptMap
        var converted = ""
        var fullyMapped = true

        for character in token {
            if character == " " {
                continue
            }
            if let mapped = mapping[character] {
                converted.append(mapped)
            } else {
                fullyMapped = false
                break
            }
        }

        if fullyMapped, !converted.isEmpty {
            return converted
        }

        if superscript {
            return "^(\(token))"
        }
        return "_(\(token))"
    }

    private static func cleanup(_ input: String) -> String {
        var output = input
            .replacingOccurrences(of: "~", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        while output.contains("  ") {
            output = output.replacingOccurrences(of: "  ", with: " ")
        }
        return output
    }

    private static func hasPrefix(_ chars: [Character], index: Int, prefix: [Character]) -> Bool {
        guard index + prefix.count <= chars.count else { return false }
        for offset in 0..<prefix.count where chars[index + offset] != prefix[offset] {
            return false
        }
        return true
    }

    private static func skipSpaces(_ chars: [Character], index: inout Int) {
        while index < chars.count, chars[index].isWhitespace {
            index += 1
        }
    }

    private static func extractArgument(_ chars: [Character], index: inout Int) -> String? {
        guard index < chars.count else { return nil }

        if chars[index] == "{" {
            index += 1
            let start = index
            var depth = 1

            while index < chars.count {
                if chars[index] == "{" {
                    depth += 1
                } else if chars[index] == "}" {
                    depth -= 1
                    if depth == 0 {
                        let value = String(chars[start..<index])
                        index += 1
                        return value
                    }
                }
                index += 1
            }
            return nil
        }

        let value = String(chars[index])
        index += 1
        return value
    }

    private static let commandReplacements: [String: String] = [
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε",
        "varepsilon": "ε", "theta": "θ", "lambda": "λ", "mu": "μ", "pi": "π",
        "rho": "ρ", "sigma": "σ", "phi": "φ", "omega": "ω",
        "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ", "Pi": "Π",
        "Sigma": "Σ", "Phi": "Φ", "Omega": "Ω",
        "times": "×", "cdot": "·", "pm": "±", "mp": "∓",
        "leq": "≤", "geq": "≥", "neq": "≠", "approx": "≈",
        "infty": "∞", "sum": "∑", "prod": "∏", "int": "∫",
        "to": "→", "rightarrow": "→", "leftarrow": "←",
        "le": "≤", "ge": "≥", "ln": "ln", "log": "log", "exp": "exp",
        "sin": "sin", "cos": "cos", "tan": "tan", "max": "max", "min": "min"
    ]

    private static let superscriptMap: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
        "n": "ⁿ", "i": "ⁱ"
    ]

    private static let subscriptMap: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
        "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ",
        "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "o": "ₒ",
        "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ",
        "v": "ᵥ", "x": "ₓ"
    ]
}
