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
        static var debtReferenceTitle: String { localized("¿Conviene adelantar?", "Should you prepay?") }
        static var debtReferencePrimaryLabel: String { localized("Costo anual estimado de tu deuda", "Estimated annual cost of your debt") }
        static var debtReferencePrimaryCaption: String { localized("Referencia anual para comparar con una TNA", "Annual reference to compare against a nominal annual rate") }
        static var debtReferenceMonthlyLabel: String { localized("Mensual estimado", "Estimated monthly") }
        static var debtReferenceMethodNote: String { localized("Estimado con tu TNA y la variación reciente de la UVA.", "Estimated using your loan rate and recent UVA variation.") }
        static var debtReferenceScenarioHigherYield: String { localized("Si una billetera o plazo fijo neto supera esta tasa, adelantar pierde atractivo.", "If a wallet or term deposit net return beats this rate, prepaying becomes less attractive.") }
        static var debtReferenceScenarioNoBetterOption: String { localized("Si no la supera, adelantar capital es la mejor opción para bajar deuda.", "If it does not beat it, prepaying principal is the best option to reduce debt.") }
        static var debtReferenceCompareCaption: String { localized("Consultá tasas de billeteras y bancos para comparar:", "Check wallet and bank rates to compare:") }
        static var debtReferenceCompareLinkLabel: String { localized("Ver tasas disponibles →", "See available rates →") }
        static var debtReferenceInsufficientData: String { localized("Todavía no hay datos suficientes para estimar esta referencia.", "There is not enough data yet to estimate this reference.") }
        static var paymentBreakdownTitle: String { localized("Desglose de la próxima cuota", "Next installment breakdown") }
        static var paymentBreakdownSubtitle: String { localized("Qué parte de la cuota amortiza capital y qué parte corresponde a interés.", "How much of the installment pays down principal and how much corresponds to interest.") }
        static var installmentCompositionAccessibility: String { localized("Composición de la cuota", "Installment composition") }
        static var historySummarySubtitle: String { localized("Evolución de las cuotas del préstamo.", "Estimated installment evolution.") }
        static var latestAdvanceSingle: String { localized("1 adelanto de capital cargado", "1 principal prepayment added") }
        static var capitalAmortizedDisplay: String { localized("Capital amortizado", "Principal amortized") }
        static var capitalCompactDisplay: String { localized("Capital", "Principal") }

        static func amortizationCaption(current: String, total: String) -> String {
            Common.completedOutOf(current, total)
        }

        static func latestAdvance(date: String, amount: String, currency: String) -> String {
            localized("Último adelanto: \(date) · \(amount) \(currency)", "Latest prepayment: \(date) · \(amount) \(currency)")
        }

        static func debtReferenceCalculatedAt(_ date: String) -> String {
            localized("Calculado al \(date)", "Calculated as of \(date)")
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

        static func reduceTermPreview(savings: String, remaining: String) -> String {
            localized("El plazo bajaría \(savings) (quedan \(remaining)).", "The term would decrease by \(savings) (\(remaining) remaining).")
        }

        static func reduceInstallmentPreview(uva: String, ars: String, usd: String) -> String {
            localized("La nueva cuota sería \(uva) (\(ars) / \(usd)).", "The new installment would be \(uva) (\(ars) / \(usd)).")
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
        static var saveLoan: String { localized("Guardar préstamo", "Save loan") }
        static var updateLoan: String { localized("Actualizar préstamo", "Update loan") }
        static var invalidTerm: String { localized("Ingresá un plazo entre 1 y 600 meses.", "Enter a term between 1 and 600 months.") }
        static var invalidRate: String { localized("La TNA debe estar entre 0% y 100%.", "The nominal annual rate must be between 0% and 100%.") }
        static var invalidAmount: String { localized("Ingresá un monto válido.", "Enter a valid amount.") }
        static var invalidInsurance: String { localized("Ingresá un seguro mayor a 0.", "Enter an insurance amount greater than 0.") }

        static func conversionPreview(uva: String, ars: String, usd: String) -> String {
            localized("Equivale a \(uva) UVA, \(ars) y \(usd) al momento del otorgamiento.", "This equals \(uva) UVA, \(ars), and \(usd) at the grant date.")
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
