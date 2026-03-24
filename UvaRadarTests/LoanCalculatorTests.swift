import Foundation
import XCTest
@testable import UvaRadar

final class LoanCalculatorTests: XCTestCase {
    func testComputeCase_WhenNoInstallmentsHaveReachedCutoff_ReturnsEmptyHistoryAndPreservesOriginalTerm() throws {
        let input = CaseInput(
            grantDate: "2024-01-15",
            firstDueDate: "2024-05-01",
            totalMonths: 12,
            tna: 0,
            originalAmount: 120,
            originalCurrency: .uva
        )
        let series = makeConstantSeries(from: "2024-01-01", through: "2024-12-31", lastCloseDate: "2024-04-15")

        let computed = try LoanCalculator.computeCase(input: input, series: series)

        XCTAssertEqual(computed.paidCount, 0)
        XCTAssertTrue(computed.history.isEmpty)
        XCTAssertEqual(computed.remainingMonths, 12)
        XCTAssertEqual(computed.balanceUVA, 120, accuracy: 0.0001)
        XCTAssertEqual(computed.principalInstallmentUVA, 10, accuracy: 0.0001)
        XCTAssertEqual(computed.nextInstallmentARS, 20, accuracy: 0.0001)
    }

    func testComputeCase_WithZeroRateAndExpiredInstallments_BuildsExpectedAmortizationHistory() throws {
        let input = CaseInput(
            grantDate: "2024-01-15",
            firstDueDate: "2024-02-01",
            totalMonths: 12,
            tna: 0,
            originalAmount: 120,
            originalCurrency: .uva
        )
        let series = makeConstantSeries(from: "2024-01-01", through: "2024-12-31", lastCloseDate: "2024-04-15")

        let computed = try LoanCalculator.computeCase(input: input, series: series)

        XCTAssertEqual(computed.paidCount, 3)
        XCTAssertEqual(computed.history.count, 3)
        XCTAssertEqual(computed.remainingMonths, 9)
        XCTAssertEqual(computed.balanceUVA, 90, accuracy: 0.0001)
        XCTAssertEqual(computed.totals.uva, 30, accuracy: 0.0001)
        assertEqual(computed.history.map(\.cuotaUVA), [10, 10, 10], accuracy: 0.0001)
    }

    func testComputeCase_WhenFutureAdvanceReducesInstallment_RecalculatesNextInstallmentBeforeItIsDue() throws {
        let input = CaseInput(
            grantDate: "2024-01-15",
            firstDueDate: "2024-02-01",
            totalMonths: 12,
            tna: 0,
            originalAmount: 120,
            originalCurrency: .uva
        )
        let series = makeConstantSeries(from: "2024-01-01", through: "2024-12-31", lastCloseDate: "2024-02-15")
        let event = CapitalAdvanceEvent(
            dateISO: "2024-02-20",
            amount: 22,
            currency: .uva,
            mode: .reduceInstallment
        )

        let computed = try LoanCalculator.computeCase(input: input, series: series, events: [event])

        XCTAssertEqual(computed.paidCount, 1)
        XCTAssertEqual(computed.history.count, 1)
        XCTAssertEqual(computed.balanceUVA, 88, accuracy: 0.0001)
        XCTAssertEqual(computed.remainingMonths, 11)
        XCTAssertEqual(computed.principalInstallmentUVA, 8, accuracy: 0.0001)
        XCTAssertEqual(computed.nextInstallmentARS, 16, accuracy: 0.0001)
    }

    func testComputeCase_WhenFutureAdvanceReducesTerm_PreservesInstallmentAndShortensRemainingTerm() throws {
        let input = CaseInput(
            grantDate: "2024-01-15",
            firstDueDate: "2024-02-01",
            totalMonths: 12,
            tna: 0,
            originalAmount: 120,
            originalCurrency: .uva
        )
        let series = makeConstantSeries(from: "2024-01-01", through: "2024-12-31", lastCloseDate: "2024-02-15")
        let event = CapitalAdvanceEvent(
            dateISO: "2024-02-20",
            amount: 30,
            currency: .uva,
            mode: .reduceTerm
        )

        let computed = try LoanCalculator.computeCase(input: input, series: series, events: [event])

        XCTAssertEqual(computed.paidCount, 1)
        XCTAssertEqual(computed.balanceUVA, 80, accuracy: 0.0001)
        XCTAssertEqual(computed.remainingMonths, 8)
        XCTAssertEqual(computed.principalInstallmentUVA, 10, accuracy: 0.0001)
        XCTAssertEqual(computed.nextInstallmentARS, 20, accuracy: 0.0001)
    }

    func testOriginalInUVA_WhenOriginalAmountIsInARS_UsesGrantDateQuote() throws {
        let input = CaseInput(
            grantDate: "2024-01-10",
            firstDueDate: "2024-02-01",
            totalMonths: 12,
            tna: 0,
            originalAmount: 240,
            originalCurrency: .ars
        )
        let series = makeConstantSeries(from: "2024-01-01", through: "2024-12-31", lastCloseDate: "2024-04-15")

        let originalUVA = try LoanCalculator.originalInUVA(input: input, series: series)

        XCTAssertEqual(originalUVA, 120, accuracy: 0.0001)
    }

    func testValueAtOrPrevious_WhenExactDateIsMissing_FallsBackToPreviousAvailableQuote() throws {
        let quotes = [
            "2024-01-09": 2.5
        ]

        let value = try LoanCalculator.valueAtOrPrevious(dateISO: "2024-01-10", series: quotes)

        XCTAssertEqual(value, 2.5, accuracy: 0.0001)
    }

    private func makeConstantSeries(
        from startISO: String,
        through endISO: String,
        lastCloseDate: String,
        uva: Double = 2,
        usd: Double = 1000
    ) -> SeriesBundle {
        var uvaSeries: [String: Double] = [:]
        var usdSeries: [String: Double] = [:]
        var currentISO = startISO

        while currentISO <= endISO {
            uvaSeries[currentISO] = uva
            usdSeries[currentISO] = usd

            guard let nextISO = ISODateSupport.addDays(1, to: currentISO) else {
                XCTFail("Failed to generate the next ISO date while building test data.")
                break
            }
            currentISO = nextISO
        }

        let years = Set([startISO.prefix(4), endISO.prefix(4), lastCloseDate.prefix(4)])
            .compactMap { Int($0) }
            .sorted()

        return SeriesBundle(
            manifest: SeriesManifest(lastCloseDate: lastCloseDate, years: years),
            uva: uvaSeries,
            usd: usdSeries
        )
    }
    private func assertEqual(
        _ actual: [Double],
        _ expected: [Double],
        accuracy: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)

        for (actualValue, expectedValue) in zip(actual, expected) {
            XCTAssertEqual(actualValue, expectedValue, accuracy: accuracy, file: file, line: line)
        }
    }
}
