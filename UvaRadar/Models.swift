import Foundation

enum LoanCurrency: String, Codable, CaseIterable, Identifiable {
    case uva = "UVA"
    case ars = "ARS"
    case usd = "USD"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .uva: return "UVA"
        case .ars: return "ARS"
        case .usd: return "USD"
        }
    }
}

enum AdvanceMode: String, Codable, CaseIterable, Identifiable {
    case reduceTerm = "REDUCE_TERM"
    case reduceInstallment = "REDUCE_INSTALLMENT"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reduceTerm: return AppStrings.AdvanceEditor.reduceTerm
        case .reduceInstallment: return AppStrings.AdvanceEditor.reduceInstallment
        }
    }
}

enum AdvancePenaltyScope: String, Codable, CaseIterable, Identifiable {
    case partial = "PARTIAL"
    case total = "TOTAL"
    case both = "BOTH"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .partial: return AppStrings.LoanEditor.penaltyScopePartial
        case .total: return AppStrings.LoanEditor.penaltyScopeTotal
        case .both: return AppStrings.LoanEditor.penaltyScopeBoth
        }
    }

    var coversPartialPrepayment: Bool {
        self == .partial || self == .both
    }
}

enum AdvancePenaltyWindowUnit: String, Codable, CaseIterable, Identifiable {
    case installments = "INSTALLMENTS"
    case months = "MONTHS"
    case years = "YEARS"
    case lifetime = "LIFETIME"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .installments: return AppStrings.LoanEditor.penaltyWindowInstallments
        case .months: return AppStrings.LoanEditor.penaltyWindowMonths
        case .years: return AppStrings.LoanEditor.penaltyWindowYears
        case .lifetime: return AppStrings.LoanEditor.penaltyWindowLifetime
        }
    }
}

struct AdvancePenaltyRule: Codable, Equatable {
    var rate: Double
    var scope: AdvancePenaltyScope
    var windowValue: Int
    var windowUnit: AdvancePenaltyWindowUnit
}

struct CaseInput: Codable, Equatable {
    var grantDate: String?
    var firstDueDate: String
    var totalMonths: Int
    var tna: Double
    var originalAmount: Double
    var originalCurrency: LoanCurrency
    var insuranceIncluded: Bool = false
    var insuranceUVA: Double = 0
    var advancePenalty: AdvancePenaltyRule? = nil
}

struct SeriesManifest: Codable, Equatable {
    let lastCloseDate: String
    let years: [Int]

    enum CodingKeys: String, CodingKey {
        case lastCloseDate = "last_close_date"
        case years
    }
}

struct SeriesBundle: Codable, Equatable {
    let manifest: SeriesManifest
    let uva: [String: Double]
    let usd: [String: Double]

    enum CodingKeys: String, CodingKey {
        case manifest
        case uva = "UVA"
        case usd = "USD"
    }
}

struct MonthlyRow: Codable, Equatable, Identifiable {
    let k: Int
    let dueDate: String
    let uvaAtDay: Double
    let usdAtDay: Double
    let cuotaUVA: Double
    let cuotaARS: Double
    let cuotaUSD: Double
    let capitalPartUVA: Double?
    let interestPartUVA: Double?
    let insurancePartUVA: Double?

    var id: Int { k }
}

struct CaseComputed: Codable, Equatable {
    let principalInstallmentUVA: Double
    let paidCount: Int
    let balanceUVA: Double
    let remainingMonths: Int
    let cutoffDate: String
    let cutoffUVA: Double
    let nextInstallmentARS: Double
    let totals: CurrencyTotals
    let history: [MonthlyRow]

    enum CodingKeys: String, CodingKey {
        case principalInstallmentUVA = "C_UVA"
        case paidCount
        case balanceUVA
        case remainingMonths
        case cutoffDate = "corteDate"
        case cutoffUVA = "corteUVA"
        case nextInstallmentARS = "nextCuotaARS"
        case totals
        case history
    }
}

struct CurrencyTotals: Codable, Equatable {
    let uva: Double
    let ars: Double
    let usd: Double

    enum CodingKeys: String, CodingKey {
        case uva = "UVA"
        case ars = "ARS"
        case usd = "USD"
    }
}

struct CapitalAdvanceEvent: Codable, Equatable, Identifiable {
    let id: UUID
    var dateISO: String
    var amount: Double
    var currency: LoanCurrency
    var mode: AdvanceMode

    init(id: UUID = UUID(), dateISO: String, amount: Double, currency: LoanCurrency, mode: AdvanceMode) {
        self.id = id
        self.dateISO = dateISO
        self.amount = amount
        self.currency = currency
        self.mode = mode
    }
}

struct PersistedCasePayload: Codable {
    let version: Int
    let input: CaseInput?
    let events: [CapitalAdvanceEvent]
}
