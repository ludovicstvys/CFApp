import Foundation

enum CFACategory: String, Codable, CaseIterable, Identifiable {
    case ethics = "Ethics"
    case quantitativeMethods = "Quantitative Methods"
    case economics = "Economics"
    case financialReporting = "Financial Reporting & Analysis"
    case corporateFinance = "Corporate Finance"
    case equity = "Equity Investments"
    case fixedIncome = "Fixed Income"
    case derivatives = "Derivatives"
    case alternativeInvestments = "Alternative Investments"
    case portfolioManagement = "Portfolio Management & Wealth Planning"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .ethics: return "Éthique"
        case .quantitativeMethods: return "Quant"
        case .economics: return "Éco"
        case .financialReporting: return "FRA"
        case .corporateFinance: return "Corp. Fin."
        case .equity: return "Equity"
        case .fixedIncome: return "Fixed Income"
        case .derivatives: return "Dérivés"
        case .alternativeInvestments: return "Alt. Inv."
        case .portfolioManagement: return "Portfolio"
        }
    }
}
