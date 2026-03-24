import Foundation

enum LoanMath {
    static func monthlyRate(fromTNA tna: Double) -> Double {
        tna / 12
    }

    static func annuityPayment(principal: Double, monthlyRate: Double, periods: Int) -> Double {
        precondition(periods > 0, "periods must be > 0")

        if monthlyRate == 0 {
            return principal / Double(periods)
        }

        let a = monthlyRate * pow(1 + monthlyRate, Double(periods))
        let b = pow(1 + monthlyRate, Double(periods)) - 1
        return principal * (a / b)
    }

    static func remainingBalance(principal: Double, monthlyRate: Double, periods: Int, paidInstallments: Int) -> Double {
        if paidInstallments == 0 {
            return principal
        }

        let installment = annuityPayment(principal: principal, monthlyRate: monthlyRate, periods: periods)

        if monthlyRate == 0 {
            return max(0, principal - installment * Double(paidInstallments))
        }

        let power = pow(1 + monthlyRate, Double(paidInstallments))
        return principal * power - installment * ((power - 1) / monthlyRate)
    }

    static func periodsToAmortize(principal: Double, monthlyRate: Double, installment: Double) -> Int {
        if principal <= 0 {
            return 0
        }

        if monthlyRate == 0 {
            return Int(ceil(principal / installment))
        }

        let denominator = installment - monthlyRate * principal
        if denominator <= 0 {
            return .max
        }

        let ratio = installment / denominator
        let periods = log(ratio) / log(1 + monthlyRate)
        return Int(ceil(periods))
    }

    static func nextBalanceAfterPayment(principal: Double, monthlyRate: Double, installment: Double) -> Double {
        max(0, principal * (1 + monthlyRate) - installment)
    }
}

enum LoanCalculator {
    static func valueAtOrPrevious(dateISO: String, series: [String: Double], maxBackDays: Int = 7) throws -> Double {
        for offset in 0...maxBackDays {
            guard let probe = ISODateSupport.addDays(-offset, to: dateISO) else { continue }
            if let value = series[probe] {
                return value
            }
        }

        throw CalculationError.missingSeriesValue(dateISO)
    }

    static func paidCountToCutoff(dueDates: [String], cutoffISO: String) -> Int {
        dueDates.filter { $0 <= cutoffISO }.count
    }

    static func originalInUVA(input: CaseInput, series: SeriesBundle) throws -> Double {
        let baseDate = input.grantDate ?? input.firstDueDate
        let uvaValue = try valueAtOrPrevious(dateISO: baseDate, series: series.uva)

        switch input.originalCurrency {
        case .uva:
            return input.originalAmount
        case .ars:
            return input.originalAmount / uvaValue
        case .usd:
            let usdValue = try valueAtOrPrevious(dateISO: baseDate, series: series.usd)
            return (input.originalAmount * usdValue) / uvaValue
        }
    }

    static func computeCase(input: CaseInput, series: SeriesBundle, events: [CapitalAdvanceEvent] = []) throws -> CaseComputed {
        let monthlyRate = LoanMath.monthlyRate(fromTNA: input.tna)
        let principalUVA = try originalInUVA(input: input, series: series)
        let totalMonths = input.totalMonths
        var principalInstallment = LoanMath.annuityPayment(principal: principalUVA, monthlyRate: monthlyRate, periods: totalMonths)
        let insurancePerMonth = input.insuranceIncluded ? input.insuranceUVA : 0

        let dueDates = generateDueDates(firstDueISO: input.firstDueDate, count: totalMonths)
        let cutoffISO = series.manifest.lastCloseDate
        let paidCount = paidCountToCutoff(dueDates: dueDates, cutoffISO: cutoffISO)
        let cutoffUVA = try valueAtOrPrevious(dateISO: cutoffISO, series: series.uva)

        let eventsWithEffectiveIndex = events
            .map { event -> (event: CapitalAdvanceEvent, effectiveInstallment: Int) in
                let effective = (dueDates.firstIndex(where: { $0 >= event.dateISO }) ?? 0) + 1
                return (event, max(1, effective))
            }
            .sorted { lhs, rhs in
                if lhs.effectiveInstallment == rhs.effectiveInstallment {
                    return lhs.event.dateISO < rhs.event.dateISO
                }
                return lhs.effectiveInstallment < rhs.effectiveInstallment
            }

        func eventUVAAmount(_ event: CapitalAdvanceEvent) throws -> Double {
            let uvaAtDay = try valueAtOrPrevious(dateISO: event.dateISO, series: series.uva)
            switch event.currency {
            case .uva:
                return event.amount
            case .ars:
                return event.amount / uvaAtDay
            case .usd:
                let usdAtDay = try valueAtOrPrevious(dateISO: event.dateISO, series: series.usd)
                return (event.amount * usdAtDay) / uvaAtDay
            }
        }

        func applyEvents(
            _ installmentEvents: [(event: CapitalAdvanceEvent, effectiveInstallment: Int)],
            balance: Double,
            installment: Double,
            remainingMonths: Int
        ) -> (balance: Double, installment: Double, remainingMonths: Int) {
            var deltaUVA = 0.0
            for item in installmentEvents {
                deltaUVA += (try? eventUVAAmount(item.event)) ?? 0
            }

            guard deltaUVA > 0 else {
                return (balance, installment, remainingMonths)
            }

            let newBalance = max(0, balance - deltaUVA)
            if newBalance == 0 {
                return (0, 0, 0)
            }

            if installmentEvents.contains(where: { $0.event.mode == .reduceInstallment }) {
                let newInstallment = LoanMath.annuityPayment(
                    principal: newBalance,
                    monthlyRate: monthlyRate,
                    periods: remainingMonths
                )
                return (newBalance, newInstallment, remainingMonths)
            }

            let periods = LoanMath.periodsToAmortize(
                principal: newBalance,
                monthlyRate: monthlyRate,
                installment: installment
            )
            let boundedPeriods = periods == .max ? remainingMonths : periods
            return (newBalance, installment, boundedPeriods)
        }

        var history: [MonthlyRow] = []
        var currentBalance = principalUVA
        var remainingMonths = totalMonths

        for installmentIndex in 0..<paidCount {
            let installmentNumber = installmentIndex + 1
            let currentEvents = eventsWithEffectiveIndex.filter { $0.effectiveInstallment == installmentNumber }
            if !currentEvents.isEmpty {
                let result = applyEvents(
                    currentEvents,
                    balance: currentBalance,
                    installment: principalInstallment,
                    remainingMonths: remainingMonths
                )
                currentBalance = result.balance
                principalInstallment = result.installment
                remainingMonths = result.remainingMonths
            }

            guard installmentNumber - 1 < dueDates.count else { break }

            let dueDate = dueDates[installmentNumber - 1]
            let uvaAtDay = try valueAtOrPrevious(dateISO: dueDate, series: series.uva)
            let usdAtDay = try valueAtOrPrevious(dateISO: dueDate, series: series.usd)
            let interestPart = currentBalance * monthlyRate
            let capitalPart = max(0, principalInstallment - interestPart)
            let totalInstallmentUVA = principalInstallment + insurancePerMonth
            let installmentARS = totalInstallmentUVA * uvaAtDay
            let installmentUSD = installmentARS / usdAtDay

            history.append(
                MonthlyRow(
                    k: installmentNumber,
                    dueDate: dueDate,
                    uvaAtDay: uvaAtDay,
                    usdAtDay: usdAtDay,
                    cuotaUVA: totalInstallmentUVA,
                    cuotaARS: installmentARS,
                    cuotaUSD: installmentUSD,
                    capitalPartUVA: capitalPart,
                    interestPartUVA: interestPart,
                    insurancePartUVA: insurancePerMonth > 0 ? insurancePerMonth : nil
                )
            )

            if remainingMonths > 0 {
                currentBalance = LoanMath.nextBalanceAfterPayment(
                    principal: currentBalance,
                    monthlyRate: monthlyRate,
                    installment: principalInstallment
                )
                remainingMonths = max(0, remainingMonths - 1)
            }
        }

        let nextInstallmentNumber = paidCount + 1
        let futureEvents = eventsWithEffectiveIndex.filter { $0.effectiveInstallment == nextInstallmentNumber }
        if !futureEvents.isEmpty, remainingMonths > 0 {
            let result = applyEvents(
                futureEvents,
                balance: currentBalance,
                installment: principalInstallment,
                remainingMonths: remainingMonths
            )
            currentBalance = result.balance
            principalInstallment = result.installment
            remainingMonths = result.remainingMonths
        }

        let totals = CurrencyTotals(
            uva: history.reduce(0) { $0 + $1.cuotaUVA },
            ars: history.reduce(0) { $0 + $1.cuotaARS },
            usd: history.reduce(0) { $0 + $1.cuotaUSD }
        )

        return CaseComputed(
            principalInstallmentUVA: principalInstallment,
            paidCount: paidCount,
            balanceUVA: currentBalance,
            remainingMonths: remainingMonths,
            cutoffDate: cutoffISO,
            cutoffUVA: cutoffUVA,
            nextInstallmentARS: principalInstallment * cutoffUVA,
            totals: totals,
            history: history
        )
    }
}

enum CalculationError: LocalizedError {
    case missingSeriesValue(String)

    var errorDescription: String? {
        switch self {
        case .missingSeriesValue(let dateISO):
            return "No se encontraron cotizaciones para la fecha \(dateISO) ni en los días hábiles previos."
        }
    }
}
