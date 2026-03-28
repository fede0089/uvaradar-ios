import Foundation

struct AdvancePenaltyEstimate: Equatable {
    let feeAmount: Double
    let totalAmount: Double
    let currency: LoanCurrency
    let effectiveInstallment: Int
    let rule: AdvancePenaltyRule
    let limitText: String
}

struct AdvancePenaltyStatus: Equatable {
    let rule: AdvancePenaltyRule
    let effectiveInstallment: Int
    let applies: Bool
    let limitText: String
}

struct DashboardPenaltyNotice: Equatable {
    let title: String
    let detail: String
    let penaltyRate: Double
    let limitText: String
}

enum AdvancePenaltyEvaluator {
    static func estimatePartialAdvanceFee(
        amount: Double,
        currency: LoanCurrency,
        eventDateISO: String,
        input: CaseInput
    ) -> AdvancePenaltyEstimate? {
        guard amount > 0,
              let rule = input.advancePenalty,
              rule.scope.coversPartialPrepayment
        else {
            return nil
        }

        let effectiveInstallment = effectiveInstallment(for: eventDateISO, input: input)
        guard applies(rule: rule, eventDateISO: eventDateISO, effectiveInstallment: effectiveInstallment, input: input) else {
            return nil
        }

        return AdvancePenaltyEstimate(
            feeAmount: amount * rule.rate,
            totalAmount: amount + (amount * rule.rate),
            currency: currency,
            effectiveInstallment: effectiveInstallment,
            rule: rule,
            limitText: limitText(for: rule, input: input)
        )
    }

    static func partialAdvanceStatus(
        eventDateISO: String,
        input: CaseInput
    ) -> AdvancePenaltyStatus? {
        guard let rule = input.advancePenalty,
              rule.scope.coversPartialPrepayment
        else {
            return nil
        }

        let effectiveInstallment = effectiveInstallment(for: eventDateISO, input: input)
        let applies = applies(rule: rule, eventDateISO: eventDateISO, effectiveInstallment: effectiveInstallment, input: input)

        return AdvancePenaltyStatus(
            rule: rule,
            effectiveInstallment: effectiveInstallment,
            applies: applies,
            limitText: limitText(for: rule, input: input)
        )
    }

    static func summaryText(for rule: AdvancePenaltyRule) -> String {
        let rateText = AppFormatting.percent(rule.rate, decimals: 1)
        let scopeText: String

        switch rule.scope {
        case .partial:
            scopeText = AppStrings.LoanEditor.penaltySummaryPartial
        case .total:
            scopeText = AppStrings.LoanEditor.penaltySummaryTotal
        case .both:
            scopeText = AppStrings.LoanEditor.penaltySummaryBoth
        }

        return AppStrings.LoanEditor.penaltySummaryFormat(
            rate: rateText,
            scope: scopeText,
            window: windowText(value: rule.windowValue, unit: rule.windowUnit)
        )
    }

    static func dashboardPenaltyNotice(referenceDateISO: String, input: CaseInput) -> DashboardPenaltyNotice? {
        guard let status = partialAdvanceStatus(eventDateISO: referenceDateISO, input: input),
              status.applies
        else {
            return nil
        }

        return DashboardPenaltyNotice(
            title: AppStrings.Dashboard.conveniencePenaltyTitle,
            detail: AppStrings.Dashboard.conveniencePenaltyDetail(
                rate: AppFormatting.percent(status.rule.rate, decimals: 1),
                limit: status.limitText
            ),
            penaltyRate: status.rule.rate,
            limitText: status.limitText
        )
    }

    static func statusText(for status: AdvancePenaltyStatus) -> String {
        if status.applies {
            return AppStrings.AdvanceEditor.penaltyStatusActive(limit: status.limitText)
        }

        return AppStrings.AdvanceEditor.penaltyStatusInactive(limit: status.limitText)
    }

    static func previewText(for estimate: AdvancePenaltyEstimate) -> String {
        AppStrings.AdvanceEditor.penaltyPreviewFormat(
            amount: AppFormatting.currency(estimate.feeAmount, currency: estimate.currency),
            rate: AppFormatting.percent(estimate.rule.rate, decimals: 1)
        )
    }

    static func totalPaymentText(for estimate: AdvancePenaltyEstimate) -> String {
        AppStrings.AdvanceEditor.totalPaymentFormat(
            total: AppFormatting.currency(estimate.totalAmount, currency: estimate.currency)
        )
    }

    static func effectiveInstallment(for eventDateISO: String, input: CaseInput) -> Int {
        let dueDates = generateDueDates(firstDueISO: input.firstDueDate, count: input.totalMonths)
        let effective = (dueDates.firstIndex(where: { $0 >= eventDateISO }) ?? 0) + 1
        return max(1, effective)
    }

    private static func applies(
        rule: AdvancePenaltyRule,
        eventDateISO: String,
        effectiveInstallment: Int,
        input: CaseInput
    ) -> Bool {
        switch rule.windowUnit {
        case .installments:
            return effectiveInstallment <= rule.windowValue
        case .months:
            return compareAgainstBoundary(eventDateISO: eventDateISO, input: input, monthsOffset: rule.windowValue)
        case .years:
            return compareAgainstBoundary(eventDateISO: eventDateISO, input: input, monthsOffset: rule.windowValue * 12)
        }
    }

    private static func compareAgainstBoundary(
        eventDateISO: String,
        input: CaseInput,
        monthsOffset: Int
    ) -> Bool {
        let baseISO = input.grantDate ?? input.firstDueDate
        guard let boundaryISO = ISODateSupport.addMonths(monthsOffset, to: baseISO) else {
            return false
        }
        return eventDateISO < boundaryISO
    }

    private static func windowText(value: Int, unit: AdvancePenaltyWindowUnit) -> String {
        switch unit {
        case .installments:
            return AppStrings.LoanEditor.penaltyWindowInstallmentsValue(value)
        case .months:
            return AppStrings.LoanEditor.penaltyWindowMonthsValue(value)
        case .years:
            return AppStrings.LoanEditor.penaltyWindowYearsValue(value)
        }
    }

    private static func limitText(for rule: AdvancePenaltyRule, input: CaseInput) -> String {
        switch rule.windowUnit {
        case .installments:
            let installmentNumber = max(1, min(rule.windowValue, input.totalMonths))
            let dueDates = generateDueDates(firstDueISO: input.firstDueDate, count: input.totalMonths)
            if dueDates.indices.contains(installmentNumber - 1) {
                return AppStrings.AdvanceEditor.penaltyAppliesUntilInstallment(
                    installmentNumber,
                    date: UIDateSupport.displayDate(from: dueDates[installmentNumber - 1])
                )
            }

            return AppStrings.AdvanceEditor.penaltyAppliesUntilInstallment(installmentNumber)

        case .months:
            return limitTextFromBoundary(monthsOffset: rule.windowValue, input: input)

        case .years:
            return limitTextFromBoundary(monthsOffset: rule.windowValue * 12, input: input)
        }
    }

    private static func limitTextFromBoundary(monthsOffset: Int, input: CaseInput) -> String {
        let baseISO = input.grantDate ?? input.firstDueDate
        guard let boundaryISO = ISODateSupport.addMonths(monthsOffset, to: baseISO),
              let lastApplicableISO = ISODateSupport.addDays(-1, to: boundaryISO)
        else {
            return AppStrings.AdvanceEditor.penaltyAppliesUntilDate(UIDateSupport.displayDate(from: baseISO))
        }

        return AppStrings.AdvanceEditor.penaltyAppliesUntilDate(
            UIDateSupport.displayDate(from: lastApplicableISO)
        )
    }
}
