import Foundation

enum ConvenienceEstimateStatus: Equatable {
    case ok
    case insufficientData
}

enum ConvenienceDecision: Equatable {
    case invest
    case prepay
    case tie
}

struct ConvenienceSimulation: Equatable {
    let amount: Double
    let currency: LoanCurrency
    let amountUVA: Double
    let horizonMonths: Int
    let investmentNominalAnnualRate: Double
    let investmentMonthlyNominalRate: Double
    let investmentMonthlyRealRate: Double
    let investmentAnnualRealRate: Double
    let futureInvestmentValueUVA: Double
    let avoidedFutureDebtUVA: Double
    let effectivePrepaymentUVA: Double
    let penaltyRate: Double?
    let penaltyApplies: Bool
    let deltaUVA: Double
    let deltaToday: Double
    let winner: ConvenienceDecision
}

struct ConvenienceEstimate: Equatable {
    let status: ConvenienceEstimateStatus
    let anchorDate: String
    let anchorUVAValue: Double
    let anchorUSDValue: Double
    let uvaMonthlyGrowthEstimate: Double
    let loanMonthlyRealRate: Double
    let loanAnnualRealRate: Double
    let loanAnnualNominalEquivalent: Double
    let loanAnnualEffectiveEquivalent: Double
    let methodNote: String

    func simulate(
        amount: Double,
        currency: LoanCurrency,
        investmentNominalAnnualRate: Double,
        horizonMonths: Int,
        penaltyRate: Double? = nil
    ) -> ConvenienceSimulation? {
        guard status == .ok,
              amount > 0,
              investmentNominalAnnualRate >= 0,
              horizonMonths > 0,
              anchorUVAValue > 0
        else {
            return nil
        }

        let amountUVA = amountInUVA(
            displayAmount: amount,
            currency: currency,
            uvaValue: anchorUVAValue,
            usdValue: anchorUSDValue
        )
        guard amountUVA.isFinite, amountUVA > 0 else {
            return nil
        }

        let investmentMonthlyNominalRate = investmentNominalAnnualRate / 12
        let investmentMonthlyRealRate = ((1 + investmentMonthlyNominalRate) / (1 + uvaMonthlyGrowthEstimate)) - 1
        guard investmentMonthlyRealRate.isFinite else {
            return nil
        }

        let effectivePenaltyRate = max(0, penaltyRate ?? 0)
        let penaltyApplies = effectivePenaltyRate > 0
        let effectivePrepaymentUVA = penaltyApplies
            ? amountUVA / (1 + effectivePenaltyRate)
            : amountUVA

        let futureInvestmentValueUVA = amountUVA * pow(1 + investmentMonthlyRealRate, Double(horizonMonths))
        let avoidedFutureDebtUVA = effectivePrepaymentUVA * pow(1 + loanMonthlyRealRate, Double(horizonMonths))
        let deltaUVA = futureInvestmentValueUVA - avoidedFutureDebtUVA
        let deltaToday = amountInDisplayCurrency(
            uvaAmount: deltaUVA,
            currency: currency,
            uvaValue: anchorUVAValue,
            usdValue: anchorUSDValue
        )
        let investmentAnnualRealRate = pow(1 + investmentMonthlyRealRate, 12) - 1

        return ConvenienceSimulation(
            amount: amount,
            currency: currency,
            amountUVA: amountUVA,
            horizonMonths: horizonMonths,
            investmentNominalAnnualRate: investmentNominalAnnualRate,
            investmentMonthlyNominalRate: investmentMonthlyNominalRate,
            investmentMonthlyRealRate: investmentMonthlyRealRate,
            investmentAnnualRealRate: investmentAnnualRealRate,
            futureInvestmentValueUVA: futureInvestmentValueUVA,
            avoidedFutureDebtUVA: avoidedFutureDebtUVA,
            effectivePrepaymentUVA: effectivePrepaymentUVA,
            penaltyRate: penaltyApplies ? effectivePenaltyRate : nil,
            penaltyApplies: penaltyApplies,
            deltaUVA: deltaUVA,
            deltaToday: deltaToday,
            winner: ConvenienceEstimator.decision(for: deltaUVA)
        )
    }

    func decisionForNominalRate(
        _ nominalAnnualRate: Double,
        penaltyRate: Double?,
        remainingMonths: Int
    ) -> ConvenienceDecision? {
        guard status == .ok, remainingMonths > 0, anchorUVAValue > 0 else { return nil }

        let investMonthlyNominal = nominalAnnualRate / 12
        let investMonthlyReal = (1 + investMonthlyNominal) / (1 + uvaMonthlyGrowthEstimate) - 1

        let effectivePrepayFactor = penaltyRate.map { 1.0 / (1 + $0) } ?? 1.0
        let T = Double(remainingMonths)
        let investFuture = pow(1 + investMonthlyReal, T)
        let prepayFuture = effectivePrepayFactor * pow(1 + loanMonthlyRealRate, T)

        return ConvenienceEstimator.decision(for: investFuture - prepayFuture)
    }
}

enum ConvenienceEstimator {
    private static let lookbackDays = 90
    private static let decisionEpsilon = 0.000_000_1

    static func defaultHorizonMonths(remainingMonths: Int) -> Int {
        max(1, remainingMonths)
    }

    static func estimate(series: SeriesBundle, input: CaseInput) -> ConvenienceEstimate {
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
              let anchorUSD = try? LoanCalculator.valueAtOrPrevious(dateISO: anchorISO, series: series.usd),
              anchorUVA > 0,
              startUVA > 0,
              anchorUSD > 0
        else {
            return insufficientData(anchorDate: anchorISO)
        }

        let totalGrowth = anchorUVA / startUVA
        guard totalGrowth.isFinite, totalGrowth > 0 else {
            return insufficientData(anchorDate: anchorISO)
        }

        let uvaMonthlyGrowthEstimate = pow(totalGrowth, 1 / elapsedMonths) - 1
        let loanMonthlyRealRate = LoanMath.monthlyRate(fromTNA: input.tna)
        let loanAnnualRealRate = pow(1 + loanMonthlyRealRate, 12) - 1
        let loanMonthlyNominalEquivalent = (1 + loanMonthlyRealRate) * (1 + uvaMonthlyGrowthEstimate) - 1
        let loanAnnualNominalEquivalent = loanMonthlyNominalEquivalent * 12
        let loanAnnualEffectiveEquivalent = pow(1 + loanMonthlyNominalEquivalent, 12) - 1

        guard uvaMonthlyGrowthEstimate.isFinite,
              loanMonthlyRealRate.isFinite,
              loanAnnualRealRate.isFinite,
              loanMonthlyNominalEquivalent.isFinite,
              loanAnnualNominalEquivalent.isFinite,
              loanAnnualEffectiveEquivalent.isFinite
        else {
            return insufficientData(anchorDate: anchorISO)
        }

        return ConvenienceEstimate(
            status: .ok,
            anchorDate: anchorISO,
            anchorUVAValue: anchorUVA,
            anchorUSDValue: anchorUSD,
            uvaMonthlyGrowthEstimate: uvaMonthlyGrowthEstimate,
            loanMonthlyRealRate: loanMonthlyRealRate,
            loanAnnualRealRate: loanAnnualRealRate,
            loanAnnualNominalEquivalent: loanAnnualNominalEquivalent,
            loanAnnualEffectiveEquivalent: loanAnnualEffectiveEquivalent,
            methodNote: AppStrings.Dashboard.convenienceMethodNote
        )
    }

    static func decision(for deltaUVA: Double) -> ConvenienceDecision {
        if deltaUVA > decisionEpsilon {
            return .invest
        }
        if deltaUVA < -decisionEpsilon {
            return .prepay
        }
        return .tie
    }

    private static func insufficientData(anchorDate: String) -> ConvenienceEstimate {
        ConvenienceEstimate(
            status: .insufficientData,
            anchorDate: anchorDate,
            anchorUVAValue: 0,
            anchorUSDValue: 0,
            uvaMonthlyGrowthEstimate: 0,
            loanMonthlyRealRate: 0,
            loanAnnualRealRate: 0,
            loanAnnualNominalEquivalent: 0,
            loanAnnualEffectiveEquivalent: 0,
            methodNote: AppStrings.Dashboard.convenienceMethodNote
        )
    }
}
