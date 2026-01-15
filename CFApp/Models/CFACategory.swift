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

    var systemImage: String {
        switch self {
        case .ethics: return "shield.lefthalf.filled"
        case .quantitativeMethods: return "function"
        case .economics: return "globe.europe.africa.fill"
        case .financialReporting: return "doc.text.magnifyingglass"
        case .corporateFinance: return "building.2.fill"
        case .equity: return "chart.line.uptrend.xyaxis"
        case .fixedIncome: return "banknote.fill"
        case .derivatives: return "arrow.triangle.2.circlepath"
        case .alternativeInvestments: return "cube.fill"
        case .portfolioManagement: return "briefcase.fill"
        }
    }
}
