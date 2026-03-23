import Foundation

enum DebtCostEstimateStatus {
    case ok
    case insufficientData
}

struct DebtCostEstimate {
    let status: DebtCostEstimateStatus
    let anchorDate: String
    let uvaMonthlyGrowthEstimate: Double
    let loanMonthlyRateUVA: Double
    let monthlyDebtCostEstimate: Double
    let annualDebtCostEquivalent: Double
    let methodNote: String
}

enum DebtCostEstimator {
    private static let lookbackDays = 90

    static func estimate(series: SeriesBundle, input: CaseInput) -> DebtCostEstimate {
        let anchorISO = series.manifest.lastCloseDate

        guard let anchorDate = ISODateSupport.parse(anchorISO),
              let startISO = ISODateSupport.addDays(-lookbackDays, to: anchorISO),
              let startDate = ISODateSupport.parse(startISO)
        else {
            return insufficientData(anchorDate: anchorISO)
        }

        let elapsedDays = max(1, Int(anchorDate.timeIntervalSince(startDate) / 86_400))
        let elapsedMonths = max(Double(elapsedDays) / 30.0, 1)

        guard let anchorUVA = try? LoanCalculator.valueAtOrPrevious(dateISO: anchorISO, series: series.uva),
              let startUVA = try? LoanCalculator.valueAtOrPrevious(dateISO: startISO, series: series.uva),
              anchorUVA > 0,
              startUVA > 0
        else {
            return insufficientData(anchorDate: anchorISO)
        }

        let totalGrowth = anchorUVA / startUVA
        guard totalGrowth.isFinite, totalGrowth > 0 else {
            return insufficientData(anchorDate: anchorISO)
        }

        let uvaMonthlyGrowthEstimate = pow(totalGrowth, 1 / elapsedMonths) - 1
        let loanMonthlyRateUVA = LoanMath.monthlyRate(fromTNA: input.tna)
        let monthlyDebtCostEstimate = (1 + loanMonthlyRateUVA) * (1 + uvaMonthlyGrowthEstimate) - 1
        let annualDebtCostEquivalent = pow(1 + monthlyDebtCostEstimate, 12) - 1

        guard uvaMonthlyGrowthEstimate.isFinite,
              loanMonthlyRateUVA.isFinite,
              monthlyDebtCostEstimate.isFinite,
              annualDebtCostEquivalent.isFinite
        else {
            return insufficientData(anchorDate: anchorISO)
        }

        return DebtCostEstimate(
            status: .ok,
            anchorDate: anchorISO,
            uvaMonthlyGrowthEstimate: uvaMonthlyGrowthEstimate,
            loanMonthlyRateUVA: loanMonthlyRateUVA,
            monthlyDebtCostEstimate: monthlyDebtCostEstimate,
            annualDebtCostEquivalent: annualDebtCostEquivalent,
            methodNote: AppStrings.Dashboard.debtReferenceMethodNote
        )
    }

    private static func insufficientData(anchorDate: String) -> DebtCostEstimate {
        DebtCostEstimate(
            status: .insufficientData,
            anchorDate: anchorDate,
            uvaMonthlyGrowthEstimate: 0,
            loanMonthlyRateUVA: 0,
            monthlyDebtCostEstimate: 0,
            annualDebtCostEquivalent: 0,
            methodNote: AppStrings.Dashboard.debtReferenceMethodNote
        )
    }
}
