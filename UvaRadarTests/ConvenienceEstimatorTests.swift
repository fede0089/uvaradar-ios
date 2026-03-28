import Foundation
import XCTest
@testable import UvaRadar

final class ConvenienceEstimatorTests: XCTestCase {
    func testEstimate_LoanRealRateDependsOnlyOnTNA() {
        let input = CaseInput(
            grantDate: "2024-01-15",
            firstDueDate: "2024-02-01",
            totalMonths: 240,
            tna: 0.24,
            originalAmount: 100,
            originalCurrency: .uva
        )

        let lowerGrowth = ConvenienceEstimator.estimate(
            series: makeSeries(lastCloseDate: "2024-04-01", startUVA: 100, anchorUVA: 110),
            input: input
        )
        let higherGrowth = ConvenienceEstimator.estimate(
            series: makeSeries(lastCloseDate: "2024-04-01", startUVA: 100, anchorUVA: 150),
            input: input
        )

        XCTAssertEqual(lowerGrowth.status, .ok)
        XCTAssertEqual(higherGrowth.status, .ok)
        XCTAssertEqual(lowerGrowth.loanMonthlyNominalRate, 0.02, accuracy: 0.0001)
        XCTAssertEqual(higherGrowth.loanMonthlyNominalRate, 0.02, accuracy: 0.0001)
        XCTAssertEqual(lowerGrowth.loanAnnualNominalCompounded, higherGrowth.loanAnnualNominalCompounded, accuracy: 0.0001)
    }

    func testSimulation_RecentUVAOnlyAffectsInvestmentConversion() {
        let input = CaseInput(
            grantDate: "2024-01-15",
            firstDueDate: "2024-02-01",
            totalMonths: 240,
            tna: 0.12,
            originalAmount: 100,
            originalCurrency: .uva
        )
        let lowerGrowth = ConvenienceEstimator.estimate(
            series: makeSeries(lastCloseDate: "2024-04-01", startUVA: 100, anchorUVA: 110),
            input: input
        )
        let higherGrowth = ConvenienceEstimator.estimate(
            series: makeSeries(lastCloseDate: "2024-04-01", startUVA: 100, anchorUVA: 140),
            input: input
        )

        let lowerGrowthSimulation = lowerGrowth.simulate(
            amount: 100,
            currency: .uva,
            investmentNominalAnnualRate: 0.18,
            horizonMonths: 24
        )
        let higherGrowthSimulation = higherGrowth.simulate(
            amount: 100,
            currency: .uva,
            investmentNominalAnnualRate: 0.18,
            horizonMonths: 24
        )

        guard let lowerGrowthSimulation, let higherGrowthSimulation else {
            XCTFail("Expected both simulations to be available.")
            return
        }

        XCTAssertEqual(
            lowerGrowthSimulation.avoidedFutureDebtUVA,
            higherGrowthSimulation.avoidedFutureDebtUVA,
            accuracy: 0.0001
        )
        XCTAssertNotEqual(
            lowerGrowthSimulation.investmentMonthlyRealRate,
            higherGrowthSimulation.investmentMonthlyRealRate
        )
    }

    func testSimulation_DeltaCanFavorInvesting() {
        let estimate = makeConstantUVAEstimate(tna: 0.12)

        let simulation = estimate.simulate(
            amount: 100,
            currency: .uva,
            investmentNominalAnnualRate: 0.24,
            horizonMonths: 12
        )

        XCTAssertEqual(simulation?.winner, .invest)
        XCTAssertGreaterThan(simulation?.deltaUVA ?? 0, 0)
    }

    func testSimulation_DeltaCanFavorPrepaying() {
        let estimate = makeConstantUVAEstimate(tna: 0.12)

        let simulation = estimate.simulate(
            amount: 100,
            currency: .uva,
            investmentNominalAnnualRate: 0.06,
            horizonMonths: 12
        )

        XCTAssertEqual(simulation?.winner, .prepay)
        XCTAssertLessThan(simulation?.deltaUVA ?? 0, 0)
    }

    func testSimulation_DeltaCanTieWithinEpsilon() {
        let estimate = makeConstantUVAEstimate(tna: 0.12)

        let simulation = estimate.simulate(
            amount: 100,
            currency: .uva,
            investmentNominalAnnualRate: 0.12,
            horizonMonths: 12
        )

        XCTAssertEqual(simulation?.winner, .tie)
        XCTAssertEqual(simulation?.deltaUVA ?? 1, 0, accuracy: 0.0000001)
    }

    func testSimulation_ConvertsVisibleAmountToUVA() {
        let estimate = makeConstantUVAEstimate(tna: 0.12, anchorUVA: 2, anchorUSD: 1000)

        let arsSimulation = estimate.simulate(
            amount: 200,
            currency: .ars,
            investmentNominalAnnualRate: 0.12,
            horizonMonths: 12
        )
        let usdSimulation = estimate.simulate(
            amount: 0.2,
            currency: .usd,
            investmentNominalAnnualRate: 0.12,
            horizonMonths: 12
        )
        let uvaSimulation = estimate.simulate(
            amount: 100,
            currency: .uva,
            investmentNominalAnnualRate: 0.12,
            horizonMonths: 12
        )

        XCTAssertEqual(arsSimulation?.amountUVA ?? 0, 100, accuracy: 0.0001)
        XCTAssertEqual(usdSimulation?.amountUVA ?? 0, 100, accuracy: 0.0001)
        XCTAssertEqual(uvaSimulation?.amountUVA ?? 0, 100, accuracy: 0.0001)
    }

    func testSimulation_WithPenalty_ReducesEffectivePrincipalBySharedBudgetFormula() {
        let estimate = makeConstantUVAEstimate(tna: 0.12)

        let simulation = estimate.simulate(
            amount: 105,
            currency: .uva,
            investmentNominalAnnualRate: 0.06,
            horizonMonths: 12,
            penaltyRate: 0.05
        )

        XCTAssertEqual(simulation?.effectivePrepaymentUVA ?? 0, 100, accuracy: 0.0001)
        XCTAssertEqual(simulation?.penaltyApplies, true)
    }

    func testSimulation_ZeroPenaltyMatchesBaseCase() {
        let estimate = makeConstantUVAEstimate(tna: 0.12)

        let base = estimate.simulate(
            amount: 100,
            currency: .uva,
            investmentNominalAnnualRate: 0.18,
            horizonMonths: 24
        )
        let zeroPenalty = estimate.simulate(
            amount: 100,
            currency: .uva,
            investmentNominalAnnualRate: 0.18,
            horizonMonths: 24,
            penaltyRate: 0
        )

        XCTAssertEqual(base, zeroPenalty)
    }

    func testSimulation_PenaltyCanFlipRecommendation() {
        let estimate = makeConstantUVAEstimate(tna: 0.12)

        let withoutPenalty = estimate.simulate(
            amount: 100,
            currency: .uva,
            investmentNominalAnnualRate: 0.114,
            horizonMonths: 24
        )
        let withPenalty = estimate.simulate(
            amount: 100,
            currency: .uva,
            investmentNominalAnnualRate: 0.114,
            horizonMonths: 24,
            penaltyRate: 0.05
        )

        XCTAssertEqual(withoutPenalty?.winner, .prepay)
        XCTAssertEqual(withPenalty?.winner, .invest)
    }

    func testDashboardCopyAndDefaults_ExposeNewConvenienceWording() {
        XCTAssertEqual(ConvenienceEstimator.defaultHorizonMonths(remainingMonths: 84), 84)
        XCTAssertTrue(AppStrings.Dashboard.conveniencePrepaymentValueLabel.contains("Deuda futura evitada"))
        XCTAssertTrue(AppStrings.Dashboard.convenienceWinnerInvest(deltaToday: "$1").contains("a valores de hoy"))
        XCTAssertTrue(AppStrings.Dashboard.convenienceDeltaTodayLabel.contains("Diferencia"))
    }

    private func makeConstantUVAEstimate(
        tna: Double,
        anchorUVA: Double = 1,
        anchorUSD: Double = 1000
    ) -> ConvenienceEstimate {
        ConvenienceEstimator.estimate(
            series: makeSeries(lastCloseDate: "2024-04-01", startUVA: anchorUVA, anchorUVA: anchorUVA, anchorUSD: anchorUSD),
            input: CaseInput(
                grantDate: "2024-01-15",
                firstDueDate: "2024-02-01",
                totalMonths: 240,
                tna: tna,
                originalAmount: 100,
                originalCurrency: .uva
            )
        )
    }

    private func makeSeries(
        lastCloseDate: String,
        startUVA: Double,
        anchorUVA: Double,
        anchorUSD: Double = 1000
    ) -> SeriesBundle {
        let startISO = ISODateSupport.addDays(-90, to: lastCloseDate) ?? "2024-01-02"
        let years = Set([lastCloseDate.prefix(4), startISO.prefix(4)])
            .compactMap { Int($0) }
            .sorted()

        return SeriesBundle(
            manifest: SeriesManifest(lastCloseDate: lastCloseDate, years: years),
            uva: [
                startISO: startUVA,
                lastCloseDate: anchorUVA
            ],
            usd: [
                lastCloseDate: anchorUSD
            ]
        )
    }
}
