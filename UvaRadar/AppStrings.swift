import Foundation

enum AppLanguage {
    case spanish
    case english
}

enum AppStrings {
    static var language: AppLanguage = .spanish

    static var localeIdentifier: String {
        switch language {
        case .spanish:
            return "es_AR"
        case .english:
            return "en_US"
        }
    }

    enum Common {
        static var appName: String { localized("UVA Radar", "UVA Radar") }
        static var add: String { localized("Agregar", "Add") }
        static var edit: String { localized("Editar", "Edit") }
        static var delete: String { localized("Borrar", "Delete") }
        static var save: String { localized("Guardar", "Save") }
        static var cancel: String { localized("Cancelar", "Cancel") }
        static var total: String { localized("Total", "Total") }
        static var period: String { localized("Período", "Period") }
        static var lastDueDate: String { localized("Último vencimiento", "Latest due date") }
        static var noData: String { localized("Sin datos", "No data") }
        static var noDate: String { localized("Sin fecha", "No date") }
        static var noUpcomingPayments: String { localized("Sin próximos pagos", "No upcoming payments") }
        static var currencyPicker: String { localized("Moneda", "Currency") }
        static var unitPicker: String { localized("Unidad", "Unit") }
        static var updatedWithClose: String { localized("Cálculos actualizados con este cierre.", "Calculations updated with this close.") }
        static var monthsUnit: String { localized("meses", "months") }

        static func months(_ count: Int) -> String {
            switch language {
            case .spanish:
                return count == 1 ? "1 mes" : "\(count) meses"
            case .english:
                return count == 1 ? "1 month" : "\(count) months"
            }
        }

        static func installments(_ count: Int) -> String {
            switch language {
            case .spanish:
                return count == 1 ? "1 cuota" : "\(count) cuotas"
            case .english:
                return count == 1 ? "1 installment" : "\(count) installments"
            }
        }

        static func remainingTime(years: Int, months: Int) -> String {
            switch language {
            case .spanish:
                if years > 0, months > 0 {
                    return "\(pluralized(years, one: "año", many: "años")) y \(pluralized(months, one: "mes", many: "meses"))"
                }
                if years > 0 {
                    return pluralized(years, one: "año", many: "años")
                }
                return pluralized(months, one: "mes", many: "meses")
            case .english:
                if years > 0, months > 0 {
                    return "\(pluralized(years, one: "year", many: "years")) and \(pluralized(months, one: "month", many: "months"))"
                }
                if years > 0 {
                    return pluralized(years, one: "year", many: "years")
                }
                return pluralized(months, one: "month", many: "months")
            }
        }

        static func remainingTimeCompact(years: Int, months: Int) -> String {
            switch language {
            case .spanish:
                if years > 0, months > 0 {
                    return "\(years) a \(months) m"
                }
                if years > 0 {
                    return "\(years) a"
                }
                return "\(months) m"
            case .english:
                if years > 0, months > 0 {
                    return "\(years) y \(months) mo"
                }
                if years > 0 {
                    return "\(years) y"
                }
                return "\(months) mo"
            }
        }

        static func completedOutOf(_ current: String, _ total: String) -> String {
            localized("\(current) de \(total)", "\(current) of \(total)")
        }
    }

    enum Content {
        static var loadingTitle: String { localized("Cargando cotizaciones", "Loading quotes") }
        static var loadingSubtitle: String { localized("Estamos preparando los datos necesarios para calcular tu préstamo.", "We are preparing the data needed to calculate your loan.") }
        static var initialLoadTitle: String { localized("Necesitás conexión para arrancar", "You need an internet connection to get started") }
        static var retryInitialDownload: String { localized("Reintentar descarga", "Retry download") }

        static func dataStatusTitle(_ date: String) -> String {
            localized("Cotizaciones al \(date)", "Quotes as of \(date)")
        }
    }

    enum Messages {
        static var quotesUpdated: String { localized("Cotizaciones actualizadas.", "Quotes updated.") }
        static var quotesAlreadyCurrent: String { localized("Ya tenés las cotizaciones más recientes.", "You already have the latest quotes.") }
        static var quotesLoaded: String { localized("Cotizaciones cargadas.", "Quotes loaded.") }
        static var initialQuotesRequired: String { localized("Necesitás conexión a internet para cargar las cotizaciones iniciales.", "You need an internet connection to load the initial quotes.") }
    }

    enum Errors {
        static var invalidSeriesURL: String { localized("La URL de series configurada no es válida.", "The configured series URL is invalid.") }
        static var invalidSeriesResponse: String { localized("La respuesta del servidor de cotizaciones no fue válida.", "The quotes server response was invalid.") }

        static func quotesDownloadFailed(code: Int) -> String {
            localized("No se pudieron descargar las cotizaciones (estado \(code)).", "Quotes could not be downloaded (status \(code)).")
        }
    }

    enum Terminology {
        static var capitalPending: String { localized("Capital pendiente", "Outstanding principal") }
        static var capitalAmortization: String { localized("Amortización de capital", "Principal amortization") }
        static var interest: String { localized("Interés", "Interest") }
        static var nextInstallment: String { localized("Próxima cuota", "Next installment") }
        static var nextDueDate: String { localized("Próximo vencimiento", "Next due date") }
        static var remainingTerm: String { localized("Plazo restante", "Remaining term") }
        static var advances: String { localized("Adelantos de capital", "Principal prepayments") }
        static var installmentHistory: String { localized("Historial de cuotas", "Installment history") }
        static var insurance: String { localized("Seguro", "Insurance") }
        static var uvaIntro: String { localized("En un crédito UVA, el préstamo se expresa en UVA y se actualiza por CER. La cuota en pesos cambia según el valor UVA vigente al momento de cada vencimiento.", "In a UVA loan, the debt is expressed in UVA and updated by CER. The installment in pesos changes according to the UVA value in effect at each due date.") }

        static func currencyContext(for currency: LoanCurrency) -> String? {
            switch currency {
            case .uva:
                return nil
            case .ars, .usd:
                return localized("Estás viendo una conversión de referencia; el préstamo sigue expresado en UVA.", "You are viewing a reference conversion; the loan is still expressed in UVA.")
            }
        }

        static func originalAmountContext(for currency: LoanCurrency) -> String? {
            switch currency {
            case .uva:
                return nil
            case .ars, .usd:
                return localized("La app convierte el monto original a UVA según la cotización del otorgamiento.", "The app converts the original amount to UVA using the grant-date quote.")
            }
        }
    }

    enum Dashboard {
        static var title: String { localized("Tu crédito hoy", "Your loan today") }
        static var progressTitle: String { localized("Avance del préstamo", "Loan progress") }
        static var progressSubtitle: String { localized("Cuánto pagaste y cuánto capital ya amortizaste.", "How much you paid and how much principal you have already amortized.") }
        static var paidInstallments: String { localized("Cuotas pagadas", "Paid installments") }
        static var contractTitle: String { localized("Condiciones de origen", "Original conditions") }
        static var contractSubtitle: String { localized("Datos del préstamo al otorgarse.", "Loan details at origination.") }
        static var grantDate: String { localized("Fecha de otorgamiento", "Grant date") }
        static var firstDueDate: String { localized("Primer vencimiento", "First due date") }
        static var nominalAnnualRate: String { localized("Tasa nominal anual (TNA)", "Nominal annual rate (NAR)") }
        static var originalTerm: String { localized("Plazo original", "Original term") }
        static var originalAmount: String { localized("Monto otorgado", "Granted amount") }
        static var initialInstallment: String { localized("Cuota inicial", "Initial installment") }
        static var advancesEmpty: String { localized("Sin adelantos cargados", "No prepayments added") }
        static var advancesDefaultSubtitle: String { localized("Pagos extraordinarios para bajar cuota o plazo.", "Extra payments to reduce the installment or shorten the term.") }
        static var convenienceTitle: String { localized("¿Conviene adelantar?", "Should you prepay?") }
        static var convenienceHeroTitle: String { localized("¿Invertir o adelantar?", "Invest or prepay?") }
        static var convenienceHeroSubtitle: String { localized("Compará patrimonio neto futuro: activo por invertir vs deuda futura evitada.", "Compare future net worth: investment asset vs future debt avoided.") }
        static var convenienceRealRateLabel: String { localized("Tasa real anual del crédito", "Loan real annual rate") }
        static var convenienceRealRateCaption: String { localized("Lo que cuesta el préstamo por encima de la inflación UVA.", "What the loan costs above UVA inflation.") }
        static var convenienceMonthlyRealRateLabel: String { localized("Tasa real mensual", "Real monthly rate") }
        static var convenienceInflationLabel: String { localized("UVA reciente mensual", "Recent monthly UVA growth") }
        static var convenienceInflationCaption: String { localized("La app usa esta variación reciente para convertir tu tasa nominal neta de inversión a tasa real.", "The app uses this recent change to convert your net nominal investment rate into a real rate.") }
        static var convenienceSimulationTitle: String { localized("Simulá con tu ahorro", "Simulate with your savings") }
        static var convenienceSimulationSubtitle: String { localized("Ingresá caja disponible, tasa nominal neta y horizonte para cuantificar la diferencia.", "Enter available cash, net nominal rate, and horizon to quantify the difference.") }
        static var convenienceAmountLabel: String { localized("Monto disponible hoy", "Amount available today") }
        static var convenienceAmountCaption: String { localized("Se interpreta como caja total. Si hay penalidad, sale de este mismo monto.", "This is treated as total cash available. If a penalty applies, it comes out of this same amount.") }
        static var convenienceInvestmentRateLabel: String { localized("Tasa nominal anual neta", "Net nominal annual rate") }
        static var convenienceInvestmentRateCaption: String { localized("Ingresala neta de impuestos, comisiones y costos relevantes.", "Enter it net of taxes, fees, and relevant costs.") }
        static var convenienceHorizonLabel: String { localized("Horizonte", "Horizon") }
        static var convenienceReadyHint: String { localized("Completá monto, tasa y horizonte para comparar invertir contra deuda futura evitada.", "Enter amount, rate, and horizon to compare investing against future debt avoided.") }
        static var convenienceConvertedRateLabel: String { localized("Tasa real anual estimada de la inversión", "Estimated real annual investment rate") }
        static var convenienceConvertedRateCaption: String { localized("Se calcula a partir de tu tasa nominal neta y la UVA reciente.", "It is calculated from your net nominal rate and recent UVA growth.") }
        static var convenienceInvestmentValueLabel: String { localized("Activo futuro por invertir", "Future asset from investing") }
        static var conveniencePrepaymentValueLabel: String { localized("Deuda futura evitada al adelantar", "Future debt avoided by prepaying") }
        static var convenienceDeltaTodayLabel: String { localized("Diferencia a valores de hoy", "Difference in today's terms") }
        static var convenienceDeltaTodayCaption: String { localized("Se muestra en la moneda visible usando la cotización de cierre actual.", "Shown in the visible currency using the current close conversion.") }
        static var convenienceDeltaUVACaption: String { localized("Referencia real equivalente en UVA al cierre actual.", "Equivalent real reference in UVA at the current close.") }
        static var convenienceEffectivePrepaymentLabel: String { localized("Capital que realmente baja deuda", "Principal that actually reduces debt") }
        static var convenienceCalculatedLabel: String { localized("Calculado al cierre", "Calculated at close") }
        static var convenienceMethodNote: String { localized("Este umbral varía con la inflación. El interés del banco es fijo; el resto se estima con datos de los últimos 90 días y puede cambiar significativamente.", "This threshold changes with inflation. The bank's interest rate is fixed; the rest is estimated from the last 90 days and can change significantly.") }
        static var convenienceCompareCaption: String { localized("Buscá tasas nominales netas para comparar y la app las pasa a real:", "Look up net nominal rates to compare and the app converts them to real terms:") }
        static var convenienceCompareLinkLabel: String { localized("Comparar con tasas de inversión →", "Compare with investment rates →") }
        static var convenienceInsufficientData: String { localized("Todavía no hay datos suficientes para estimar esta comparación.", "There is not enough data yet to estimate this comparison.") }
        static var paymentBreakdownTitle: String { localized("Desglose de la próxima cuota", "Next installment breakdown") }
        static var paymentBreakdownSubtitle: String { localized("Qué parte de la cuota amortiza capital y qué parte corresponde a interés.", "How much of the installment pays down principal and how much corresponds to interest.") }
        static var installmentCompositionAccessibility: String { localized("Composición de la cuota", "Installment composition") }
        static var historySummarySubtitle: String { localized("Evolución de las cuotas del préstamo.", "Estimated installment evolution.") }
        static var latestAdvanceSingle: String { localized("1 adelanto de capital cargado", "1 principal prepayment added") }
        static var capitalAmortizedDisplay: String { localized("Capital amortizado", "Principal amortized") }
        static var capitalCompactDisplay: String { localized("Capital", "Principal") }
        static var conveniencePenaltyTitle: String { localized("La penalidad reduce el capital efectivo", "Penalty reduces the effective principal") }

        static func conveniencePenaltyInputHint(rate: String, limit: String) -> String {
            localized(
                "Penalidad activa: \(rate) (\(limit)). Se descuenta del capital que baja deuda.",
                "Active penalty: \(rate) (\(limit)). Deducted from the principal that reduces debt."
            )
        }

        static var convenienceRateInputLabel: String {
            localized("¿A qué tasa podés invertir?", "What rate can you invest at?")
        }

        static var convenienceThresholdLabel: String {
            localized("Tasa de corte en pesos (ARS)", "Break-even rate in pesos (ARS)")
        }

        static var convenienceThresholdCaption: String {
            localized(
                "Si encontrás una inversión en pesos que supere este % TNA, conviene invertir en lugar de adelantar capital.",
                "If you find a peso investment that beats this % TNA, investing beats prepaying."
            )
        }

        static var convenienceSheetBalanceLabel: String {
            localized("Tenés un capital pendiente de", "You have a pending balance of")
        }

        static var convenienceSheetCostPerMillionLabel: String {
            localized("Por cada $1M de capital, en un mes:", "Per $1M of capital, in one month:")
        }

        static var convenienceBreakdownTotal: String {
            localized("Total mensual:", "Monthly total:")
        }

        static var convenienceBreakdownAnnualized: String {
            localized("Al año:", "Annualized:")
        }

        static func convenienceSheetDecisionInvest(amount: String, threshold: String) -> String {
            localized(
                "Si invertís ese $1M y generás más de \(amount)/mes (= \(threshold) TNA), cubrís lo que genera la deuda y te sobra — conviene invertir.",
                "If you invest that $1M and generate more than \(amount)/month (= \(threshold) TNA), you cover the debt cost and profit — investing wins."
            )
        }

        static func convenienceSheetDecisionPrepay(amount: String) -> String {
            localized(
                "Si generás menos de \(amount)/mes, conviene adelantar: te ahorrás más en la deuda de lo que ganarías invirtiendo.",
                "If you generate less than \(amount)/month, prepaying wins: you save more on debt than you'd earn by investing."
            )
        }

        static var convenienceBreakdownTitle: String {
            localized("¿De dónde sale ese monto?", "Where does that amount come from?")
        }

        static func convenienceBreakdownInterest(tna: String) -> String {
            localized("① Interés del banco (\(tna) TNA)", "① Bank interest (\(tna) TNA)")
        }

        static func convenienceBreakdownInflation(monthly: String) -> String {
            localized("② Ajuste por inflación (~\(monthly)/mes)", "② Inflation adjustment (~\(monthly)/month)")
        }

        static func convenienceBreakdownFormula(monthly: String) -> String {
            localized("\(monthly)/mes × 12 = ", "\(monthly)/month × 12 = ")
        }

        static func convenienceDecisionInvest(threshold: String) -> String {
            localized("Tu inversión rinde más del \(threshold) TNA → invertir conviene más", "Your investment yields above \(threshold) TNA → investing is better")
        }

        static func convenienceDecisionPrepay(threshold: String) -> String {
            localized("Tu inversión rinde menos del \(threshold) TNA → adelantar conviene más", "Your investment yields below \(threshold) TNA → prepaying is better")
        }

        static var convenienceMethodSheetTitle: String {
            localized("La regla de tu crédito", "Your Loan's Rule")
        }

        static var convenienceSheetRuleTitle: String {
            localized("Tu tasa de corte en pesos (ARS)", "Your break-even rate in pesos (ARS)")
        }

        static var convenienceSheetRuleCaption: String {
            localized(
                "La tasa en pesos (TNA) que necesitás superar para que invertir sea mejor que adelantar.",
                "The rate in pesos (TNA) you need to beat for investing to be better than prepaying."
            )
        }

        static var convenienceSheetDecisionContext: String {
            localized("Aplicá esta regla a tu situación:", "Apply this rule to your situation:")
        }

        static func convenienceSheetDecisionInvestCondition(threshold: String) -> String {
            localized("Si podés conseguir más del \(threshold) TNA", "If you can get more than \(threshold) TNA")
        }

        static var convenienceSheetDecisionInvestConsequence: String {
            localized(
                "Mejor invertir — tu ganancia supera el costo de la deuda.",
                "Better to invest — your return exceeds the cost of the debt."
            )
        }

        static func convenienceSheetDecisionPrepayCondition(threshold: String) -> String {
            localized("Si no llegás al \(threshold) TNA", "If you can't reach \(threshold) TNA")
        }

        static var convenienceSheetDecisionPrepayConsequence: String {
            localized(
                "Mejor adelantar capital — lo que ahorrás supera lo que ganarías.",
                "Better to prepay — what you save beats what you'd earn."
            )
        }

        static var convenienceSheetWhereFromTitle: String {
            localized("Ejemplo", "Example")
        }

        static var convenienceSheetWhereFromIntro: String {
            localized(
                "Suponé que tenés $1M de pesos disponibles. Ese capital le genera mensualmente a tu préstamo:",
                "Suppose you have $1M pesos available. This capital generates the following monthly cost on your loan:"
            )
        }

        static func convenienceSheetCostInsight(total: String, threshold: String) -> String {
            localized(
                "Anualizado, eso equivale al \(threshold) TNA. Para que valga la pena invertir en lugar de adelantar, necesitás que ese capital genere más de ~\(total)/mes. Si lo superás, cubrís el costo de la deuda y te queda ganancia.",
                "Annualized, that's equivalent to \(threshold) TNA. For investing to beat prepaying, you need that capital to generate more than ~\(total)/month. If it does, you cover the cost of the debt and profit."
            )
        }

        static func convenienceSheetWhereFromFormula(monthly: String, threshold: String) -> String {
            localized(
                "~\(monthly)/mes × 12 = \(threshold) TNA",
                "~\(monthly)/month × 12 = \(threshold) TNA"
            )
        }

        static var convenienceSheetWhereFromDisclaimer: String {
            localized(
                "El ajuste UVA se estima con datos de los últimos 90 días. La inflación real puede ser diferente — el umbral varía.",
                "The UVA adjustment is estimated from the last 90 days. Actual inflation may differ — the threshold can change."
            )
        }

        static func convenienceExampleSectionTitle(balance: String) -> String {
            localized("Tu deuda de \(balance) en 1 mes", "Your \(balance) debt in 1 month")
        }

        static func convenienceExampleIntro(balance: String) -> String {
            localized(
                "Tu capital pendiente de \(balance) genera este costo mensual. ¿Conviene cubrirlo con una inversión o adelantar?",
                "Your pending balance of \(balance) generates this monthly cost. Is it better to cover it with an investment or prepay?"
            )
        }

        static func convenienceExamplePrepayLabel(balance: String) -> String {
            localized("Si adelantás \(balance)", "If you prepay \(balance)")
        }

        static var convenienceExamplePrepayDetail: String {
            localized("de deuda que no crece este mes", "in debt that won't grow this month")
        }

        static func convenienceExampleInvestLabel(rate: String) -> String {
            localized("Si lo ponés en un plazo fijo al \(rate) TNA", "If you put it in a savings account at \(rate) TNA")
        }

        static var convenienceExampleInvestDetail: String {
            localized("de retorno en un mes", "in returns in one month")
        }

        static func convenienceExampleBreakeven(threshold: String) -> String {
            localized(
                "Resultado idéntico. Porque \(threshold) TNA ÷ 12 = la tasa mensual exacta de tu deuda.\nEste umbral aplica igual a 1 mes que a 12: si tu inversión supera el \(threshold) TNA, siempre conviene más.",
                "Identical outcome. Because \(threshold) TNA ÷ 12 = the exact monthly rate of your debt.\nThis threshold applies at any horizon — 1 month or 12: if your investment exceeds \(threshold) TNA, it always wins."
            )
        }

        static var convenienceExampleCaption: String {
            localized(
                "Inflación estimada con datos de los últimos 90 días. El resultado real puede variar.",
                "Inflation estimated from the last 90 days of data. Actual results may vary."
            )
        }

        static var convenienceHowCalculatedTitle: String {
            localized("Explicación paso a paso", "Step-by-step explanation")
        }

        static var convenienceSheetHowToUseTitle: String {
            localized("¿Cómo lo usás?", "How do you use this?")
        }

        static var convenienceSheetHowToUseBody: String {
            localized(
                "Consultá la tasa nominal anual (TNA) de tu inversión actual — plazo fijo, FCI, billetera virtual — y compará con este número.\nSi tu inversión rinde más: mejor invertir el dinero.\nSi rinde menos: mejor usar ese dinero para adelantar capital.",
                "Check the nominal annual rate (TNA) of your current investment — fixed term, mutual fund, digital wallet — and compare it with this number.\nIf your investment yields more: better to invest.\nIf it yields less: better to use that money to prepay capital."
            )
        }

        static var convenienceMethodIntro: String {
            localized(
                "Un crédito UVA tiene dos costos al mismo tiempo. Para que valga la pena invertir, tu inversión tiene que ganarle a los dos.",
                "A UVA loan has two simultaneous costs. For investing to be worthwhile, your investment needs to beat both."
            )
        }

        static func convenienceMethodStep1(tna: String, monthly: String) -> String {
            localized(
                "① El banco te cobra interés: \(tna) TNA\nEso es \(monthly) de interés por mes, sobre el capital que debés.",
                "① The bank charges you interest: \(tna) TNA\nThat is \(monthly) of interest per month on the balance you owe."
            )
        }

        static func convenienceMethodStep2(uvaMonthly: String) -> String {
            localized(
                "② La deuda sube con la inflación: ~\(uvaMonthly) por mes\nLos créditos UVA se actualizan por inflación (CER). Si los precios subieron ~\(uvaMonthly) este mes, tu deuda en pesos también subió ~\(uvaMonthly).",
                "② The debt rises with inflation: ~\(uvaMonthly) per month\nUVA loans are inflation-indexed (CER). If prices rose ~\(uvaMonthly) this month, your peso debt also rose ~\(uvaMonthly)."
            )
        }

        static func convenienceMethodFormula(monthlyRate: String, threshold: String, tea: String) -> String {
            localized(
                "Combinando ambos:\n\(monthlyRate) por mes × 12 = \(threshold) TNA (≈ \(tea) TEA)\nSi te cotizan la inversión en TEA, compará contra el \(tea).",
                "Combining both:\n\(monthlyRate) per month × 12 = \(threshold) TNA (≈ \(tea) TEA)\nIf the investment is quoted in TEA, compare against \(tea)."
            )
        }

        static func convenienceMethodConclusion(threshold: String) -> String {
            localized(
                "Si conseguís una inversión neta (después de impuestos) que rinda más del \(threshold) TNA, el dinero crece más rápido que tu deuda → conviene invertir.\n\nSi no llegás a ese \(threshold), adelantar el crédito te da un beneficio equivalente a esa tasa, sin riesgo de mercado — aunque ese dinero queda comprometido en el crédito y no es fácilmente recuperable.",
                "If you find a net investment (after taxes) yielding more than \(threshold) TNA, your money grows faster than your debt → investing is better.\n\nIf you can't reach that \(threshold), prepaying your loan gives you the equivalent return without market risk — though that money is committed to the loan and not easily accessible."
            )
        }

        static func convenienceWinnerInvestNominal(rate: String, threshold: String) -> String {
            localized(
                "Conviene invertir: el \(rate) que ingresaste supera el umbral de \(threshold).",
                "Investing is better: the \(rate) you entered beats the \(threshold) threshold."
            )
        }

        static func convenienceWinnerPrepayNominal(rate: String, threshold: String) -> String {
            localized(
                "Conviene adelantar: el \(rate) que ingresaste no llega al umbral de \(threshold).",
                "Prepaying is better: the \(rate) you entered does not reach the \(threshold) threshold."
            )
        }

        static var convenienceWinnerTieNominal: String {
            localized(
                "Estás justo en el umbral: las dos opciones son equivalentes.",
                "You are right at the break-even: both options are equivalent."
            )
        }

        static func conveniencePenaltyDetail(rate: String, limit: String) -> String {
            localized("Si adelantás hoy, tu banco cobraría \(rate) sobre el monto usado para adelantar (vigente \(limit)). La simulación descuenta esa comisión del capital que realmente baja deuda.", "If you prepay today, your bank would charge \(rate) on the amount used to prepay (in force \(limit)). The simulation subtracts that fee from the principal that actually reduces debt.")
        }

        static func conveniencePenaltyImpact(effectiveCapital: String, totalBudget: String, rate: String) -> String {
            localized("Con penalidad, solo \(effectiveCapital) de \(totalBudget) bajarían deuda (\(rate) se va en comisión).", "With the penalty, only \(effectiveCapital) of \(totalBudget) would reduce debt (\(rate) goes to fees).")
        }

        static func convenienceWinnerInvest(deltaToday: String) -> String {
            localized("Invertir ganaría por \(deltaToday) a valores de hoy.", "Investing would win by \(deltaToday) in today's terms.")
        }

        static func convenienceWinnerPrepay(deltaToday: String) -> String {
            localized("Adelantar ganaría por \(deltaToday) a valores de hoy.", "Prepaying would win by \(deltaToday) in today's terms.")
        }

        static var convenienceWinnerTie: String { localized("Las dos alternativas quedan prácticamente empatadas.", "Both alternatives are effectively tied.") }

        static func convenienceCalculatedAt(_ date: String) -> String {
            localized("Calculado al \(date)", "Calculated as of \(date)")
        }

        static func amortizationCaption(current: String, total: String) -> String {
            Common.completedOutOf(current, total)
        }

        static func latestAdvance(date: String, amount: String, currency: String) -> String {
            localized("Último adelanto: \(date) · \(amount) \(currency)", "Latest prepayment: \(date) · \(amount) \(currency)")
        }

        static func advanceCount(_ count: Int) -> String {
            switch language {
            case .spanish:
                return count == 1 ? latestAdvanceSingle : "\(count) adelantos de capital cargados"
            case .english:
                return count == 1 ? latestAdvanceSingle : "\(count) principal prepayments added"
            }
        }

        static func advanceSummary(date: String, mode: String) -> String {
            localized("\(date) · \(mode)", "\(date) · \(mode)")
        }
    }

    enum History {
        static var overviewSubtitle: String { localized("Evolución de cada cuota del préstamo.", "Estimated evolution of each loan installment.") }
        static var registeredInstallments: String { localized("Cuotas registradas", "Recorded installments") }
        static var registeredInstallmentsSubtitle: String { localized("Cuotas del préstamo", "Loan installments") }
        static var totalEstimated: String { localized("Total estimado", "Estimated total") }
        static var totalEstimatedSubtitle: String { localized("Suma de todas las cuotas", "Sum of all installments") }
        static var latestDueDateSubtitle: String { localized("Cuota más reciente del historial", "Most recent installment in the history") }
        static var historyStart: String { localized("Inicio del historial", "History start") }
        static var historyStartSubtitle: String { localized("Primera cuota", "First installment") }
        static var chartTitle: String { localized("Evolución de cuotas", "Installment evolution") }
        static var flatSeriesNote: String { localized("La cuota se mantuvo bastante estable en todo el período visible.", "The installment remained fairly stable throughout the visible period.") }

        static func historyCount(_ count: Int) -> String {
            switch language {
            case .spanish:
                return count == 1 ? "1 cuota estimada" : "\(count) cuotas estimadas"
            case .english:
                return count == 1 ? "1 estimated installment" : "\(count) estimated installments"
            }
        }

        static func installmentTitle(_ number: Int) -> String {
            localized("Cuota \(number)", "Installment \(number)")
        }
    }

    enum AdvanceEditor {
        static var date: String { localized("Fecha", "Date") }
        static var amount: String { localized("Monto", "Amount") }
        static var effect: String { localized("Efecto del adelanto", "Prepayment effect") }
        static var sectionTitle: String { localized("Nuevo adelanto de capital", "New principal prepayment") }
        static var footer: String { localized("El impacto se aplica desde el siguiente vencimiento compatible con la fecha cargada.", "The impact is applied from the next due date compatible with the selected date.") }
        static var impact: String { localized("Impacto", "Impact") }
        static var navigationTitle: String { localized("Registrar adelanto", "Add prepayment") }
        static var invalidAmount: String { localized("Ingresá un monto válido.", "Enter a valid amount.") }
        static var reduceTerm: String { localized("Reducir plazo", "Reduce term") }
        static var reduceInstallment: String { localized("Reducir cuota", "Reduce installment") }
        static var penaltyTitle: String { localized("Penalidad estimada", "Estimated penalty") }
        static var penaltyContractTitle: String { localized("Penalidad contractual", "Contract penalty") }
        static var totalPaymentTitle: String { localized("Total a pagar", "Total to pay") }

        static func reduceTermPreview(savings: String, remaining: String) -> String {
            localized("El plazo bajaría \(savings) (quedan \(remaining)).", "The term would decrease by \(savings) (\(remaining) remaining).")
        }

        static func reduceInstallmentPreview(uva: String, ars: String, usd: String) -> String {
            localized("La nueva cuota sería \(uva) (\(ars) / \(usd)).", "The new installment would be \(uva) (\(ars) / \(usd)).")
        }

        static func penaltyPreviewFormat(amount: String, rate: String) -> String {
            localized("Tu banco cobraría \(amount) de penalidad (\(rate) sobre el monto).", "Your bank would charge \(amount) as a penalty (\(rate) on the amount).")
        }

        static func totalPaymentFormat(total: String) -> String {
            localized("Adelanto + penalidad = \(total)", "Prepayment + penalty = \(total)")
        }

        static func penaltyStatusActive(limit: String) -> String {
            localized("La penalidad aplica para este adelanto — vigente \(limit).", "The penalty applies to this prepayment — in force \(limit).")
        }

        static func penaltyStatusInactive(limit: String) -> String {
            localized("Sin penalidad para esta fecha. La vigencia terminó \(limit).", "No penalty for this date. The period ended \(limit).")
        }

        static func penaltyAppliesUntilDate(_ date: String) -> String {
            localized("hasta el \(date)", "until \(date)")
        }

        static func penaltyAppliesUntilInstallment(_ installment: Int, date: String) -> String {
            localized("hasta la cuota \(installment) (vencimiento \(date))", "through installment \(installment) (due \(date))")
        }

        static func penaltyAppliesUntilInstallment(_ installment: Int) -> String {
            localized("hasta la cuota \(installment)", "through installment \(installment)")
        }
    }

    enum LoanEditor {
        static var createTitle: String { localized("Cargá los datos del préstamo", "Enter the loan details") }
        static var editTitle: String { localized("Editar préstamo", "Edit loan") }
        static var createSubtitle: String { localized("Ingresá las condiciones de origen para empezar el seguimiento.", "Enter the original conditions to start tracking the loan.") }
        static var editSubtitle: String { localized("Ajustá los datos del préstamo y actualizamos la simulación.", "Adjust the loan details and we will update the simulation.") }
        static var originSectionTitle: String { localized("Condiciones de origen", "Original conditions") }
        static var originSectionSubtitle: String { localized("Fechas clave y plazo inicial.", "Key dates and initial term.") }
        static var originalTermTitle: String { localized("Plazo original", "Original term") }
        static var originalTermCaption: String { localized("Cantidad total de cuotas.", "Total number of installments.") }
        static var financeSectionTitle: String { localized("Condiciones financieras", "Financial conditions") }
        static var financeSectionSubtitle: String { localized("Monto, tasa y unidad de carga.", "Amount, rate, and input unit.") }
        static var tnaCaption: String { localized("Ingresá la tasa nominal anual.", "Enter the nominal annual rate.") }
        static var originalAmountCaption: String { localized("Importe original del préstamo.", "Original loan amount.") }
        static var amountInputUnitTitle: String { localized("Moneda o unidad de carga", "Currency or input unit") }
        static var insuranceSectionTitle: String { localized("Seguro del bien", "Property insurance") }
        static var insuranceSectionSubtitle: String { localized("Solo si se suma dentro de la cuota.", "Only if it is included in the installment.") }
        static var includeInsurance: String { localized("Incluir seguro dentro de la cuota", "Include insurance in the installment") }
        static var includeInsuranceSubtitle: String { localized("Se suma al importe de cada cuota.", "It is added to each installment amount.") }
        static var includedInsuranceTitle: String { localized("Seguro incluido en cuota", "Insurance included in installment") }
        static var includedInsuranceCaption: String { localized("Monto fijo en UVA por cuota.", "Fixed UVA amount per installment.") }
        static var penaltySectionTitle: String { localized("Penalidad por adelanto", "Prepayment penalty") }
        static var penaltySectionSubtitle: String { localized("Opcional. Algunos contratos cobran una comisión si adelantás capital durante los primeros meses o años del préstamo.", "Optional. Some contracts charge a fee if you prepay principal during the first months or years of the loan.") }
        static var includePenalty: String { localized("Mi contrato incluye penalidad por adelanto", "My contract includes a prepayment penalty") }
        static var includePenaltySubtitle: String { localized("Si no la cargás, asumimos que no aplica.", "If you do not enter it, we assume it does not apply.") }
        static var penaltyRateTitle: String { localized("Porcentaje que cobra el banco", "Percentage charged by the bank") }
        static var penaltyRateCaption: String { localized("El banco te cobra este porcentaje sobre el capital que adelantás.", "The bank charges this percentage on the capital you prepay.") }
        static var penaltyScopeTitle: String { localized("¿A qué adelantos aplica?", "Which prepayments does it apply to?") }
        static var penaltyWindowTitle: String { localized("¿Por cuánto tiempo aplica?", "How long does it apply?") }
        static var penaltyWindowCaption: String { localized("Mirá tu contrato: puede decir \"primeras X cuotas\", \"primeros X meses\" o \"primeros X años\".", "Check your contract: it may say \"first X installments\", \"first X months\", or \"first X years\".") }
        static var penaltyWindowValueTitle: String { localized("Cantidad", "Amount") }
        static var penaltyScopePartial: String { localized("Solo parciales", "Partial only") }
        static var penaltyScopeTotal: String { localized("Cancelación total", "Full payoff only") }
        static var penaltyScopeBoth: String { localized("Ambos tipos", "Both types") }
        static var penaltySummaryPartial: String { localized("adelantos parciales", "partial prepayments") }
        static var penaltySummaryTotal: String { localized("cancelación total", "full prepayment") }
        static var penaltySummaryBoth: String { localized("adelantos parciales o cancelación total", "partial or full prepayments") }
        static var penaltyWindowInstallments: String { localized("Cuotas", "Installments") }
        static var penaltyWindowMonths: String { localized("Meses", "Months") }
        static var penaltyWindowYears: String { localized("Años", "Years") }
        static var penaltyContractSummaryTitle: String { localized("Penalidad contractual", "Contract penalty") }
        static var saveLoan: String { localized("Guardar préstamo", "Save loan") }
        static var updateLoan: String { localized("Actualizar préstamo", "Update loan") }
        static var invalidTerm: String { localized("Ingresá un plazo entre 1 y 600 meses.", "Enter a term between 1 and 600 months.") }
        static var invalidRate: String { localized("La TNA debe estar entre 0% y 100%.", "The nominal annual rate must be between 0% and 100%.") }
        static var invalidAmount: String { localized("Ingresá un monto válido.", "Enter a valid amount.") }
        static var invalidInsurance: String { localized("Ingresá un seguro mayor a 0.", "Enter an insurance amount greater than 0.") }
        static var invalidPenaltyRate: String { localized("Ingresá una penalidad entre 0% y 100%.", "Enter a penalty between 0% and 100%.") }
        static var invalidPenaltyWindow: String { localized("Ingresá una ventana válida para la penalidad.", "Enter a valid penalty window.") }

        static func conversionPreview(uva: String, ars: String, usd: String) -> String {
            localized("Equivale a \(uva) UVA, \(ars) y \(usd) al momento del otorgamiento.", "This equals \(uva) UVA, \(ars), and \(usd) at the grant date.")
        }

        static func penaltySummaryFormat(rate: String, scope: String, window: String) -> String {
            localized("\(rate) sobre \(scope) durante \(window).", "\(rate) on \(scope) during \(window).")
        }

        static func penaltyWindowInstallmentsValue(_ value: Int) -> String {
            localized("las primeras \(value) cuotas", "the first \(value) installments")
        }

        static func penaltyWindowMonthsValue(_ value: Int) -> String {
            localized("los primeros \(value) meses", "the first \(value) months")
        }

        static func penaltyWindowYearsValue(_ value: Int) -> String {
            localized("los primeros \(value) años", "the first \(value) years")
        }
    }

    static func localized(_ spanish: String, _ english: String) -> String {
        switch language {
        case .spanish:
            return spanish
        case .english:
            return english
        }
    }

    private static func pluralized(_ value: Int, one: String, many: String) -> String {
        value == 1 ? "1 \(one)" : "\(value) \(many)"
    }
}
