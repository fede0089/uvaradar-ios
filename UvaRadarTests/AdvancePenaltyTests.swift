import Foundation
import XCTest
@testable import UvaRadar

final class AdvancePenaltyTests: XCTestCase {
    func testCaseInputDecodesOldPayloadWithoutAdvancePenalty() throws {
        let data = """
        {
          "firstDueDate": "2024-02-01",
          "grantDate": "2024-01-15",
          "insuranceIncluded": false,
          "insuranceUVA": 0,
          "originalAmount": 120,
          "originalCurrency": "UVA",
          "tna": 0.1,
          "totalMonths": 120
        }
        """.data(using: .utf8)!

        let input = try JSONDecoder().decode(CaseInput.self, from: data)

        XCTAssertNil(input.advancePenalty)
    }

    func testEstimatePartialAdvanceFee_WhenRuleCoversInstallmentWindow_ReturnsFee() {
        let input = CaseInput(
            grantDate: "2024-01-15",
            firstDueDate: "2024-02-01",
            totalMonths: 120,
            tna: 0.1,
            originalAmount: 100_000,
            originalCurrency: .ars,
            advancePenalty: AdvancePenaltyRule(
                rate: 0.03,
                scope: .partial,
                windowValue: 12,
                windowUnit: .installments
            )
        )

        let estimate = AdvancePenaltyEvaluator.estimatePartialAdvanceFee(
            amount: 1_000,
            currency: .ars,
            eventDateISO: "2024-05-10",
            input: input
        )

        XCTAssertNotNil(estimate)
        XCTAssertEqual(estimate!.feeAmount, 30, accuracy: 0.0001)
        XCTAssertEqual(estimate!.totalAmount, 1_030, accuracy: 0.0001)
        XCTAssertEqual(estimate!.effectiveInstallment, 5)
        XCTAssertEqual(estimate!.limitText, "hasta la cuota 12 (vencimiento 31/12/2024)")
    }

    func testEstimatePartialAdvanceFee_WhenRuleOnlyCoversTotalCancellation_ReturnsNil() {
        let input = CaseInput(
            grantDate: "2024-01-15",
            firstDueDate: "2024-02-01",
            totalMonths: 120,
            tna: 0.1,
            originalAmount: 100_000,
            originalCurrency: .ars,
            advancePenalty: AdvancePenaltyRule(
                rate: 0.03,
                scope: .total,
                windowValue: 24,
                windowUnit: .months
            )
        )

        let estimate = AdvancePenaltyEvaluator.estimatePartialAdvanceFee(
            amount: 1_000,
            currency: .ars,
            eventDateISO: "2024-05-10",
            input: input
        )

        XCTAssertNil(estimate)
    }

    func testPartialAdvanceStatus_WhenRuleUsesMonths_ReturnsActiveUntilDate() {
        let input = CaseInput(
            grantDate: "2024-01-15",
            firstDueDate: "2024-02-01",
            totalMonths: 120,
            tna: 0.1,
            originalAmount: 100_000,
            originalCurrency: .ars,
            advancePenalty: AdvancePenaltyRule(
                rate: 0.03,
                scope: .partial,
                windowValue: 6,
                windowUnit: .months
            )
        )

        let status = AdvancePenaltyEvaluator.partialAdvanceStatus(
            eventDateISO: "2024-05-10",
            input: input
        )

        XCTAssertEqual(status?.applies, true)
        XCTAssertEqual(status?.limitText, "hasta el 13/07/2024")
    }

    func testPartialAdvanceStatus_WhenRuleExpired_ReturnsInactive() {
        let input = CaseInput(
            grantDate: "2024-01-15",
            firstDueDate: "2024-02-01",
            totalMonths: 120,
            tna: 0.1,
            originalAmount: 100_000,
            originalCurrency: .ars,
            advancePenalty: AdvancePenaltyRule(
                rate: 0.03,
                scope: .partial,
                windowValue: 6,
                windowUnit: .months
            )
        )

        let status = AdvancePenaltyEvaluator.partialAdvanceStatus(
            eventDateISO: "2024-08-01",
            input: input
        )

        XCTAssertEqual(status?.applies, false)
        XCTAssertEqual(status?.limitText, "hasta el 13/07/2024")
    }

    func testPartialAdvanceStatus_WhenRuleOnlyCoversTotalCancellation_ReturnsNil() {
        let input = CaseInput(
            grantDate: "2024-01-15",
            firstDueDate: "2024-02-01",
            totalMonths: 120,
            tna: 0.1,
            originalAmount: 100_000,
            originalCurrency: .ars,
            advancePenalty: AdvancePenaltyRule(
                rate: 0.03,
                scope: .total,
                windowValue: 12,
                windowUnit: .installments
            )
        )

        let status = AdvancePenaltyEvaluator.partialAdvanceStatus(
            eventDateISO: "2024-05-10",
            input: input
        )

        XCTAssertNil(status)
    }

    func testDashboardPenaltyNotice_WhenPenaltyApplies_ExplainsEffectiveCapitalReduction() {
        let input = CaseInput(
            grantDate: "2024-01-15",
            firstDueDate: "2024-02-01",
            totalMonths: 120,
            tna: 0.1,
            originalAmount: 100_000,
            originalCurrency: .ars,
            advancePenalty: AdvancePenaltyRule(
                rate: 0.03,
                scope: .partial,
                windowValue: 12,
                windowUnit: .installments
            )
        )

        let notice = AdvancePenaltyEvaluator.dashboardPenaltyNotice(
            referenceDateISO: "2024-05-10",
            input: input
        )

        XCTAssertEqual(notice?.title, "La penalidad reduce el capital efectivo")
        XCTAssertTrue(notice?.detail.contains("3,0%") == true)
        XCTAssertTrue(notice?.detail.contains("hasta la cuota 12") == true)
        XCTAssertTrue(notice?.detail.contains("realmente baja deuda") == true)
    }

    func testDashboardPenaltyNotice_WhenRuleOnlyCoversTotalCancellation_ReturnsNil() {
        let input = CaseInput(
            grantDate: "2024-01-15",
            firstDueDate: "2024-02-01",
            totalMonths: 120,
            tna: 0.1,
            originalAmount: 100_000,
            originalCurrency: .ars,
            advancePenalty: AdvancePenaltyRule(
                rate: 0.03,
                scope: .total,
                windowValue: 12,
                windowUnit: .installments
            )
        )

        let warning = AdvancePenaltyEvaluator.dashboardPenaltyNotice(
            referenceDateISO: "2024-05-10",
            input: input
        )

        XCTAssertNil(warning)
    }

    func testTotalPaymentText_WhenPenaltyApplies_ReturnsCombinedAmount() {
        let input = CaseInput(
            grantDate: "2024-01-15",
            firstDueDate: "2024-02-01",
            totalMonths: 120,
            tna: 0.1,
            originalAmount: 100_000,
            originalCurrency: .ars,
            advancePenalty: AdvancePenaltyRule(
                rate: 0.03,
                scope: .partial,
                windowValue: 12,
                windowUnit: .installments
            )
        )

        let estimate = AdvancePenaltyEvaluator.estimatePartialAdvanceFee(
            amount: 1_000,
            currency: .ars,
            eventDateISO: "2024-05-10",
            input: input
        )

        let totalText = AdvancePenaltyEvaluator.totalPaymentText(for: estimate!)
        XCTAssertTrue(totalText.contains("Adelanto + penalidad"))
        XCTAssertTrue(totalText.contains("1.030,00"))
    }
}
