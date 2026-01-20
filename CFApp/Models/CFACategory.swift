import Foundation

struct CFACategory: Hashable, Codable, Identifiable {
    let rawValue: String

    var id: String { rawValue }

    init(_ rawValue: String) {
        self.rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(rawValue: String) {
        self.init(rawValue)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self.init(raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var shortName: String {
        if let info = Self.knownInfo[normalizedKey] {
            return info.shortName
        }
        return rawValue
    }

    var systemImage: String {
        if let info = Self.knownInfo[normalizedKey] {
            return info.systemImage
        }
        return "tag"
    }

    static func parse(_ raw: String) -> CFACategory? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let canonical = canonicalName(for: trimmed)
        return CFACategory(canonical)
    }

    static func canonicalName(for raw: String) -> String {
        let key = normalizeKey(raw)
        if let mapped = knownAliases[key] {
            return mapped
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedKey: String {
        Self.normalizeKey(rawValue)
    }

    private static func normalizeKey(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let folded = trimmed.folding(options: .diacriticInsensitive, locale: .current)
        return folded.lowercased()
    }

    private struct CategoryInfo {
        let shortName: String
        let systemImage: String
    }

    private static let knownInfo: [String: CategoryInfo] = [
        normalizeKey("Ethics"): CategoryInfo(shortName: "Éthique", systemImage: "shield.lefthalf.filled"),
        normalizeKey("Quantitative Methods"): CategoryInfo(shortName: "Quant", systemImage: "function"),
        normalizeKey("Economics"): CategoryInfo(shortName: "Éco", systemImage: "globe.europe.africa.fill"),
        normalizeKey("Financial Reporting & Analysis"): CategoryInfo(shortName: "FRA", systemImage: "doc.text.magnifyingglass"),
        normalizeKey("Corporate Finance"): CategoryInfo(shortName: "Corp. Fin.", systemImage: "building.2.fill"),
        normalizeKey("Equity Investments"): CategoryInfo(shortName: "Equity", systemImage: "chart.line.uptrend.xyaxis"),
        normalizeKey("Fixed Income"): CategoryInfo(shortName: "Fixed Income", systemImage: "banknote.fill"),
        normalizeKey("Derivatives"): CategoryInfo(shortName: "Dérivés", systemImage: "arrow.triangle.2.circlepath"),
        normalizeKey("Alternative Investments"): CategoryInfo(shortName: "Alt. Inv.", systemImage: "cube.fill"),
        normalizeKey("Portfolio Management & Wealth Planning"): CategoryInfo(shortName: "Portfolio", systemImage: "briefcase.fill")
    ]

    private static let knownAliases: [String: String] = [
        normalizeKey("ethics"): "Ethics",
        normalizeKey("ethique"): "Ethics",
        normalizeKey("quantitative methods"): "Quantitative Methods",
        normalizeKey("quantitative"): "Quantitative Methods",
        normalizeKey("quant"): "Quantitative Methods",
        normalizeKey("qm"): "Quantitative Methods",
        normalizeKey("economics"): "Economics",
        normalizeKey("economie"): "Economics",
        normalizeKey("financial reporting & analysis"): "Financial Reporting & Analysis",
        normalizeKey("financial reporting and analysis"): "Financial Reporting & Analysis",
        normalizeKey("fra"): "Financial Reporting & Analysis",
        normalizeKey("corporate finance"): "Corporate Finance",
        normalizeKey("corp fin"): "Corporate Finance",
        normalizeKey("equity investments"): "Equity Investments",
        normalizeKey("equity"): "Equity Investments",
        normalizeKey("fixed income"): "Fixed Income",
        normalizeKey("fi"): "Fixed Income",
        normalizeKey("derivatives"): "Derivatives",
        normalizeKey("derives"): "Derivatives",
        normalizeKey("alternative investments"): "Alternative Investments",
        normalizeKey("alts"): "Alternative Investments",
        normalizeKey("portfolio management & wealth planning"): "Portfolio Management & Wealth Planning",
        normalizeKey("portfolio management and wealth planning"): "Portfolio Management & Wealth Planning",
        normalizeKey("portfolio management"): "Portfolio Management & Wealth Planning",
        normalizeKey("portfolio"): "Portfolio Management & Wealth Planning"
    ]
}
