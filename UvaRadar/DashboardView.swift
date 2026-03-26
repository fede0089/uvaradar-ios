import Charts
import SwiftUI

struct DashboardView: View {
    let model: AppModel
    let series: SeriesBundle

    @State private var displayCurrency: LoanCurrency = .uva
    @State private var showingAdvanceSheet = false
    @State private var contractExpanded = false
    @State private var advancesExpanded = false

    var body: some View {
        if let input = model.input, let computed = model.computed {
            let snapshot = DashboardSnapshot(input: input, computed: computed, series: series, currency: displayCurrency)

            VStack(spacing: 18) {
                primaryStatusCard(snapshot: snapshot, input: input, computed: computed)
                progressSummaryCard(input: input, computed: computed)
                contractSummaryCard(input: input, computed: computed)
                advancesSummaryCard
                historySummaryCard(computed: computed)
            }
            .sheet(isPresented: $showingAdvanceSheet) {
                AdvanceEditorView(series: series, input: input, computed: computed) { event in
                    model.addAdvance(event)
                }
            }
        } else {
            EmptyView()
        }
    }

    private func primaryStatusCard(snapshot: DashboardSnapshot, input: CaseInput, computed: CaseComputed) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(AppStrings.Dashboard.title)
                            .font(.title3.weight(.semibold))
                    }

                    Spacer()

                    Picker(AppStrings.Common.currencyPicker, selection: $displayCurrency) {
                        ForEach(LoanCurrency.allCases) { currency in
                            Text(currency.displayName).tag(currency)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .frame(maxWidth: 204)
                }

                if let currencyContext = UvaTerminology.currencyContext(for: displayCurrency) {
                    Text(currencyContext)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let debtCostEstimate = model.debtCostEstimate {
                    DebtCostReferenceCard(estimate: debtCostEstimate)
                }

                StatusMetricsGrid(items: [
                    StatusMetric(
                        title: UvaTerminology.nextInstallment,
                        value: AppFormatting.currency(snapshot.nextInstallment, currency: displayCurrency),
                        isHighlighted: true
                    ),
                    StatusMetric(
                        title: UvaTerminology.capitalPending,
                        value: AppFormatting.currency(snapshot.pendingBalance, currency: displayCurrency)
                    ),
                    StatusMetric(
                        title: AppStrings.Terminology.nextDueDate,
                        value: snapshot.nextDueDateText
                    ),
                    StatusMetric(
                        title: UvaTerminology.remainingTerm,
                        value: formatRemainingTime(computed.remainingMonths)
                    )
                ])

                PaymentBreakdownSummary(
                    slices: installmentCompositionSlices(
                        capital: snapshot.capitalComponent,
                        interest: snapshot.interestComponent,
                        insurance: input.insuranceIncluded ? snapshot.insuranceComponent : nil,
                        currency: displayCurrency
                    )
                )
            }
        }
    }

    private func progressSummaryCard(input: CaseInput, computed: CaseComputed) -> some View {
        let originalUVA = (try? LoanCalculator.originalInUVA(input: input, series: series)) ?? 0
        let totalPlannedNow = computed.paidCount + computed.remainingMonths
        let installmentsProgress = totalPlannedNow > 0 ? Double(computed.paidCount) / Double(totalPlannedNow) : 0
        let amortized = max(0, originalUVA - computed.balanceUVA)
        let amortizedProgress = originalUVA > 0 ? amortized / originalUVA : 0

        return CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(AppStrings.Dashboard.progressTitle)
                        .font(.headline)
                    Text(AppStrings.Dashboard.progressSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    ProgressMetricRow(
                        title: AppStrings.Dashboard.paidInstallments,
                        value: installmentsProgress,
                        caption: AppStrings.Common.completedOutOf("\(computed.paidCount)", "\(max(totalPlannedNow, 1))")
                    )
                    ProgressMetricRow(
                        title: UvaTerminology.capitalAmortization,
                        value: amortizedProgress,
                        caption: AppStrings.Dashboard.amortizationCaption(
                            current: AppFormatting.number(amortized, decimals: 0),
                            total: "\(AppFormatting.number(originalUVA, decimals: 0)) UVA"
                        )
                    )
                }
            }
        }
    }

    private func contractSummaryCard(input: CaseInput, computed: CaseComputed) -> some View {
        let baseDate = input.grantDate ?? input.firstDueDate
        let baseUVA = (try? LoanCalculator.valueAtOrPrevious(dateISO: baseDate, series: series.uva)) ?? 0
        let baseUSD = (try? LoanCalculator.valueAtOrPrevious(dateISO: baseDate, series: series.usd)) ?? 1
        let originalUVA = (try? LoanCalculator.originalInUVA(input: input, series: series)) ?? 0
        let installmentWithInsurance = computed.principalInstallmentUVA + (input.insuranceIncluded ? input.insuranceUVA : 0)
        let initialAmount = amountInDisplayCurrency(uvaAmount: originalUVA, currency: displayCurrency, uvaValue: baseUVA, usdValue: baseUSD)
        let initialInstallment = amountInDisplayCurrency(uvaAmount: installmentWithInsurance, currency: displayCurrency, uvaValue: baseUVA, usdValue: baseUSD)

        return CardContainer(emphasis: .subtle) {
            DisclosureGroup(isExpanded: $contractExpanded) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Spacer()

                        Button {
                            model.beginEditingCase()
                        } label: {
                            Label(AppStrings.Common.edit, systemImage: "square.and.pencil")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(role: .destructive) {
                            model.clearCase()
                        } label: {
                            Label(AppStrings.Common.delete, systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    MetricsGrid(items: [
                        MetricItem(title: AppStrings.Dashboard.grantDate, value: UIDateSupport.displayDate(from: baseDate), symbol: nil, tint: .secondary, compact: true),
                        MetricItem(title: AppStrings.Dashboard.firstDueDate, value: UIDateSupport.displayDate(from: input.firstDueDate), symbol: nil, tint: .secondary, compact: true),
                        MetricItem(title: AppStrings.Dashboard.nominalAnnualRate, value: AppFormatting.number(input.tna * 100, decimals: 2) + "%", symbol: nil, tint: .secondary, compact: true),
                        MetricItem(title: AppStrings.Dashboard.originalTerm, value: formatRemainingTime(input.totalMonths), symbol: nil, tint: .secondary, compact: true),
                        MetricItem(title: AppStrings.Dashboard.originalAmount, value: AppFormatting.currency(initialAmount, currency: displayCurrency), symbol: nil, tint: .secondary, compact: true),
                        MetricItem(title: AppStrings.Dashboard.initialInstallment, value: AppFormatting.currency(initialInstallment, currency: displayCurrency), symbol: nil, tint: .secondary, compact: true)
                    ])
                }
                .padding(.top, 14)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppStrings.Dashboard.contractTitle)
                        .font(.headline)
                    Text(AppStrings.Dashboard.contractSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .tint(.primary)
        }
    }

    private var advancesSummaryCard: some View {
        CardContainer(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(UvaTerminology.advances)
                            .font(.headline)
                        Text(advancesSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        AppAnalytics.shared.track(.advanceEditorOpened, properties: [
                            "existing_advance_count": model.events.count
                        ])
                        showingAdvanceSheet = true
                    } label: {
                        Label(AppStrings.Common.add, systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if model.events.isEmpty {
                    Text(AppStrings.Dashboard.advancesEmpty)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    DisclosureGroup(isExpanded: $advancesExpanded) {
                        VStack(spacing: 10) {
                            ForEach(model.events.sorted(by: { $0.dateISO > $1.dateISO })) { event in
                                AdvanceSummaryRow(event: event) {
                                    model.removeAdvance(event.id)
                                }
                            }
                        }
                        .padding(.top, 12)
                    } label: {
                        AdvanceSummaryHeader(eventCount: model.events.count, latestEvent: latestAdvance)
                    }
                    .tint(.primary)
                }
            }
        }
    }

    private func historySummaryCard(computed: CaseComputed) -> some View {
        NavigationLink {
            PaymentHistoryView(computed: computed, initialCurrency: displayCurrency)
        } label: {
            CardContainer(emphasis: .subtle) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(UvaTerminology.installmentHistory)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(AppStrings.Dashboard.historySummarySubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }

                    HistorySummaryInline(
                        periodText: historyPeriodText(for: computed),
                        latestDueDateText: latestDueDateText(for: computed)
                    )
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var latestAdvance: CapitalAdvanceEvent? {
        model.events.max(by: { $0.dateISO < $1.dateISO })
    }

    private var advancesSubtitle: String {
        if let latestAdvance {
            return AppStrings.Dashboard.latestAdvance(
                date: UIDateSupport.displayDate(from: latestAdvance.dateISO),
                amount: AppFormatting.number(latestAdvance.amount, decimals: 2),
                currency: latestAdvance.currency.displayName
            )
        }
        return AppStrings.Dashboard.advancesDefaultSubtitle
    }

    private func historyPeriodText(for computed: CaseComputed) -> String {
        let rows = computed.history.sorted(by: { $0.dueDate < $1.dueDate })
        guard let first = rows.first, let last = rows.last else { return AppStrings.Common.noData }
        return "\(UIDateSupport.displayMonthYear(from: first.dueDate)) - \(UIDateSupport.displayMonthYear(from: last.dueDate))"
    }

    private func latestDueDateText(for computed: CaseComputed) -> String {
        let rows = computed.history.sorted(by: { $0.dueDate < $1.dueDate })
        guard let last = rows.last else { return AppStrings.Common.noData }
        return UIDateSupport.displayDate(from: last.dueDate)
    }
}

private struct DashboardSnapshot {
    let pendingBalance: Double
    let nextInstallment: Double
    let capitalComponent: Double
    let interestComponent: Double
    let insuranceComponent: Double
    let installmentsProgress: Double
    let nextDueDateText: String

    init(input: CaseInput, computed: CaseComputed, series: SeriesBundle, currency: LoanCurrency) {
        let cutoffUSD = (try? LoanCalculator.valueAtOrPrevious(dateISO: computed.cutoffDate, series: series.usd)) ?? 1
        let insuranceUVA = input.insuranceIncluded ? input.insuranceUVA : 0
        let totalInstallmentUVA = computed.principalInstallmentUVA + insuranceUVA
        let monthlyRate = LoanMath.monthlyRate(fromTNA: input.tna)
        let interestUVA = computed.balanceUVA * monthlyRate
        let capitalUVA = max(0, computed.principalInstallmentUVA - interestUVA)
        let totalPlannedNow = max(1, computed.paidCount + computed.remainingMonths)
        let nextDueISO = generateDueDates(firstDueISO: input.firstDueDate, count: input.totalMonths)
            .dropFirst(computed.paidCount)
            .first

        pendingBalance = amountInDisplayCurrency(uvaAmount: computed.balanceUVA, currency: currency, uvaValue: computed.cutoffUVA, usdValue: cutoffUSD)
        nextInstallment = amountInDisplayCurrency(uvaAmount: totalInstallmentUVA, currency: currency, uvaValue: computed.cutoffUVA, usdValue: cutoffUSD)
        capitalComponent = amountInDisplayCurrency(uvaAmount: capitalUVA, currency: currency, uvaValue: computed.cutoffUVA, usdValue: cutoffUSD)
        interestComponent = amountInDisplayCurrency(uvaAmount: interestUVA, currency: currency, uvaValue: computed.cutoffUVA, usdValue: cutoffUSD)
        insuranceComponent = amountInDisplayCurrency(uvaAmount: insuranceUVA, currency: currency, uvaValue: computed.cutoffUVA, usdValue: cutoffUSD)
        installmentsProgress = Double(computed.paidCount) / Double(totalPlannedNow)
        nextDueDateText = nextDueISO.map { UIDateSupport.displayDate(from: $0) } ?? AppStrings.Common.noUpcomingPayments
    }
}

private struct InstallmentCompositionSlice: Identifiable {
    let id: String
    let title: String
    let value: Double
    let formattedValue: String
    let color: Color

    var percentText: String { AppFormatting.percent(percentage, decimals: 0) }

    var mainDisplayTitle: String {
        switch id {
        case "capital":
            return AppStrings.Dashboard.capitalAmortizedDisplay
        default:
            return title
        }
    }

    var compactDisplayTitle: String {
        switch id {
        case "capital":
            return AppStrings.Dashboard.capitalCompactDisplay
        default:
            return title
        }
    }

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return value / total
    }

    var total: Double = 0
}

private func installmentCompositionSlices(
    capital: Double,
    interest: Double,
    insurance: Double?,
    currency: LoanCurrency
) -> [InstallmentCompositionSlice] {
    let safeCapital = max(0, capital)
    let safeInterest = max(0, interest)
    let safeInsurance = max(0, insurance ?? 0)
    let total = safeCapital + safeInterest + safeInsurance

    var slices = [
        InstallmentCompositionSlice(
            id: "capital",
            title: UvaTerminology.capitalAmortization,
            value: safeCapital,
            formattedValue: AppFormatting.currency(capital, currency: currency),
            color: .blue.opacity(0.78),
            total: total
        ),
        InstallmentCompositionSlice(
            id: "interest",
            title: UvaTerminology.interest,
            value: safeInterest,
            formattedValue: AppFormatting.currency(interest, currency: currency),
            color: .secondary.opacity(0.92),
            total: total
        )
    ]

    if safeInsurance > 0 {
        slices.append(
            InstallmentCompositionSlice(
                id: "insurance",
                title: AppStrings.Terminology.insurance,
                value: safeInsurance,
                formattedValue: AppFormatting.currency(safeInsurance, currency: currency),
                color: .teal.opacity(0.76),
                total: total
            )
        )
    }

    return slices.filter { $0.value > 0 }
}

private struct StatusMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String?
    let isHighlighted: Bool

    init(title: String, value: String, subtitle: String? = nil, isHighlighted: Bool = false) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.isHighlighted = isHighlighted
    }
}

private struct StatusMetricsGrid: View {
    let items: [StatusMetric]

    private let columns = [
        GridItem(.flexible(minimum: 140), spacing: 10),
        GridItem(.flexible(minimum: 140), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.isHighlighted ? .primary : .secondary)

                    Text(item.value)
                        .font(item.isHighlighted ? .title3.weight(.semibold) : .headline)
                        .minimumScaleFactor(0.82)
                        .lineLimit(2)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(metricBackground(for: item), in: .rect(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(item.isHighlighted ? Color.accentColor.opacity(0.16) : Color.clear, lineWidth: 1)
                }
            }
        }
    }

    private func metricBackground(for item: StatusMetric) -> Color {
        item.isHighlighted ? Color.accentColor.opacity(0.10) : Color(uiColor: .secondarySystemBackground)
    }
}

private struct PaymentBreakdownSummary: View {
    let slices: [InstallmentCompositionSlice]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppStrings.Dashboard.paymentBreakdownTitle)
                .font(.subheadline.weight(.semibold))

            Text(AppStrings.Dashboard.paymentBreakdownSubtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 16) {
                InstallmentCompositionDonut(slices: slices, size: 84)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(slices) { slice in
                        CompositionLegendRow(
                            title: slice.mainDisplayTitle,
                            value: slice.formattedValue,
                            color: slice.color,
                            detail: slice.percentText
                        )
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct CompositionLegendRow: View {
    let title: String
    let value: String
    let color: Color
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 14))
    }
}

private struct InstallmentCompositionDonut: View {
    let slices: [InstallmentCompositionSlice]
    var size: CGFloat = 72

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Monto", slice.value),
                innerRadius: .ratio(0.62),
                angularInset: 2
            )
            .foregroundStyle(slice.color)
            .cornerRadius(4)
        }
        .chartLegend(.hidden)
        .chartBackground { _ in Color.clear }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppStrings.Dashboard.installmentCompositionAccessibility)
        .accessibilityValue(
            slices
                .map { "\($0.title): \($0.formattedValue)" }
                .joined(separator: ", ")
        )
    }
}

private struct AdvanceSummaryHeader: View {
    let eventCount: Int
    let latestEvent: CapitalAdvanceEvent?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AppStrings.Dashboard.advanceCount(eventCount))
                .font(.subheadline.weight(.semibold))
            if let latestEvent {
                Text(AppStrings.Dashboard.advanceSummary(date: UIDateSupport.displayDate(from: latestEvent.dateISO), mode: latestEvent.mode.title))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DebtCostReferenceCard: View {
    let estimate: DebtCostEstimate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.Dashboard.debtReferenceHeroTitle)
                    .font(.headline)
                Text(AppStrings.Dashboard.debtReferenceHeroSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            switch estimate.status {
            case .ok:
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppStrings.Dashboard.debtReferenceThresholdLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(AppFormatting.percent(estimate.annualDebtCostEquivalent, decimals: 1))
                            .font(.title2.weight(.bold))
                            .accessibilityLabel(AppStrings.Dashboard.debtReferenceThresholdLabel)

                        Text(AppStrings.Dashboard.debtReferenceThresholdCaption)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.accentColor.opacity(0.10), in: .rect(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 8) {
                        decisionRow(
                            symbol: "chart.line.uptrend.xyaxis",
                            text: AppStrings.Dashboard.debtReferenceInvestingUpside
                        )
                        decisionRow(
                            symbol: "arrow.down.left.circle",
                            text: AppStrings.Dashboard.debtReferencePrepayingUpside
                        )
                    }

                    ViewThatFits {
                        HStack(spacing: 10) {
                            referencePill(
                                title: AppStrings.Dashboard.debtReferenceMonthlyLabel,
                                value: AppFormatting.percent(estimate.monthlyDebtCostEstimate, decimals: 1)
                            )
                            referencePill(
                                title: AppStrings.Dashboard.debtReferenceCalculatedLabel,
                                value: UIDateSupport.displayDate(from: estimate.anchorDate)
                            )
                        }

                        VStack(spacing: 10) {
                            referencePill(
                                title: AppStrings.Dashboard.debtReferenceMonthlyLabel,
                                value: AppFormatting.percent(estimate.monthlyDebtCostEstimate, decimals: 1)
                            )
                            referencePill(
                                title: AppStrings.Dashboard.debtReferenceCalculatedLabel,
                                value: UIDateSupport.displayDate(from: estimate.anchorDate)
                            )
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppStrings.Dashboard.debtReferenceCompareCaption)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Link(destination: URL(string: "https://comparatasas.ar")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                Text(AppStrings.Dashboard.debtReferenceCompareLinkLabel)
                            }
                            .font(.footnote.weight(.semibold))
                        }
                    }

                    Text(estimate.methodNote)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

            case .insufficientData:
                Text(AppStrings.Dashboard.debtReferenceInsufficientData)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }

    private func decisionRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
    }

    private func referencePill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground).opacity(0.6), in: .rect(cornerRadius: 14))
    }
}

private struct AdvanceSummaryRow: View {
    let event: CapitalAdvanceEvent
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(UIDateSupport.displayDate(from: event.dateISO))
                    .font(.subheadline.weight(.semibold))
                Text("\(AppFormatting.number(event.amount, decimals: 2)) \(event.currency.displayName)")
                    .font(.subheadline)
                Text(event.mode.title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 16))
    }
}

private struct HistorySummaryInline: View {
    let periodText: String
    let latestDueDateText: String

    var body: some View {
        ViewThatFits {
            HStack(spacing: 14) {
                summaryBlock(title: AppStrings.Common.period, value: periodText)
                Divider()
                    .frame(height: 24)
                summaryBlock(title: AppStrings.Common.lastDueDate, value: latestDueDateText)
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 10) {
                summaryBlock(title: AppStrings.Common.period, value: periodText)
                summaryBlock(title: AppStrings.Common.lastDueDate, value: latestDueDateText)
            }
        }
    }

    private func summaryBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}

struct PaymentHistoryView: View {
    let computed: CaseComputed

    @State private var currency: LoanCurrency
    @State private var expandedYears: Set<Int>
    @State private var didTrackOpen = false

    init(computed: CaseComputed, initialCurrency: LoanCurrency) {
        self.computed = computed
        _currency = State(initialValue: initialCurrency)
        _expandedYears = State(initialValue: Self.defaultExpandedYears(from: computed.history))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                historyOverviewCard

                LazyVStack(spacing: 12) {
                    ForEach(yearGroups) { group in
                        CardContainer(emphasis: .subtle) {
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedYears.contains(group.year) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedYears.insert(group.year)
                                        } else {
                                            expandedYears.remove(group.year)
                                        }
                                    }
                                )
                            ) {
                                VStack(spacing: 10) {
                                    ForEach(group.rows) { row in
                                        HistoryCompactRow(row: row, currency: currency)
                                    }
                                }
                                .padding(.top, 12)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(String(group.year))
                                            .font(.headline)
                                        Text(AppStrings.Common.installments(group.rows.count))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(
            AppBackground()
                .ignoresSafeArea()
        )
        .navigationTitle(UvaTerminology.installmentHistory)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didTrackOpen else { return }
            didTrackOpen = true
            AppAnalytics.shared.track(.paymentHistoryOpened, properties: [
                "installment_count": computed.history.count,
                "initial_currency": currency.rawValue
            ])
        }
    }

    private var historyOverviewCard: some View {
        let points = historyPoints
        let totalValue = points.reduce(0) { $0 + $1.value }
        let flatSeries = isFlatSeries(points)

        return CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(UvaTerminology.installmentHistory)
                        .font(.headline)
                    Text(AppStrings.History.overviewSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Picker(AppStrings.Common.unitPicker, selection: $currency) {
                    ForEach(LoanCurrency.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if let currencyContext = UvaTerminology.currencyContext(for: currency) {
                    Text(currencyContext)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                StatusMetricsGrid(items: [
                    StatusMetric(
                        title: AppStrings.History.registeredInstallments,
                        value: "\(computed.history.count)",
                        subtitle: AppStrings.History.registeredInstallmentsSubtitle
                    ),
                    StatusMetric(
                        title: AppStrings.History.totalEstimated,
                        value: AppFormatting.currency(totalValue, currency: currency),
                        subtitle: AppStrings.History.totalEstimatedSubtitle
                    ),
                    StatusMetric(
                        title: AppStrings.Common.lastDueDate,
                        value: latestInstallmentDate,
                        subtitle: AppStrings.History.latestDueDateSubtitle
                    ),
                    StatusMetric(
                        title: AppStrings.History.historyStart,
                        value: firstInstallmentDate,
                        subtitle: AppStrings.History.historyStartSubtitle
                    )
                ])

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(AppStrings.History.chartTitle)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(AppStrings.History.historyCount(computed.history.count))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Chart(points) { point in
                        LineMark(
                            x: .value(AppStrings.AdvanceEditor.date, point.date),
                            y: .value(AppStrings.AdvanceEditor.amount, point.value)
                        )
                        .foregroundStyle(.secondary)
                        .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }
                    .frame(height: 220)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .year, count: 2)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.quaternary)
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(UIDateSupport.chartMonthYear(from: date))
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.quaternary)
                            AxisValueLabel()
                        }
                    }

                    if flatSeries {
                        Text(AppStrings.History.flatSeriesNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var historyPoints: [HistoryPoint] {
        sortedHistory
            .compactMap { row in
                guard let date = ISODateSupport.parse(row.dueDate) else { return nil }
                return HistoryPoint(id: row.id, date: date, value: rowValue(row))
            }
    }

    private var yearGroups: [HistoryYearGroup] {
        let grouped = Dictionary(grouping: computed.history.sorted(by: { $0.dueDate > $1.dueDate })) { row in
            year(for: row.dueDate)
        }

        return grouped.keys.sorted(by: >).map { year in
            HistoryYearGroup(year: year, rows: grouped[year] ?? [])
        }
    }

    private var latestInstallmentDate: String {
        guard let lastRow = sortedHistory.last else { return AppStrings.Common.noDate }
        return UIDateSupport.displayDate(from: lastRow.dueDate)
    }

    private var firstInstallmentDate: String {
        guard let firstRow = sortedHistory.first else { return AppStrings.Common.noDate }
        return UIDateSupport.displayDate(from: firstRow.dueDate)
    }

    private var sortedHistory: [MonthlyRow] {
        computed.history.sorted(by: { $0.dueDate < $1.dueDate })
    }

    private func rowValue(_ row: MonthlyRow) -> Double {
        switch currency {
        case .uva:
            return row.cuotaUVA
        case .ars:
            return row.cuotaARS
        case .usd:
            return row.cuotaUSD
        }
    }

    private func year(for iso: String) -> Int {
        guard let date = ISODateSupport.parse(iso) else { return 0 }
        return Calendar(identifier: .gregorian).component(.year, from: date)
    }

    private func isFlatSeries(_ points: [HistoryPoint]) -> Bool {
        let values = points.map(\.value)
        let maxValue = values.max() ?? 0
        let minValue = values.min() ?? 0
        let threshold = max(1, maxValue * 0.01)
        return points.count > 1 && (maxValue - minValue) <= threshold
    }

    private static func defaultExpandedYears(from rows: [MonthlyRow]) -> Set<Int> {
        let latestYear = rows
            .compactMap { ISODateSupport.parse($0.dueDate) }
            .map { Calendar(identifier: .gregorian).component(.year, from: $0) }
            .max()

        return latestYear.map { [$0] } ?? []
    }
}

private struct HistoryYearGroup: Identifiable {
    let year: Int
    let rows: [MonthlyRow]

    var id: Int { year }
}

private struct HistoryPoint: Identifiable {
    let id: Int
    let date: Date
    let value: Double
}

private struct HistoryCompactRow: View {
    let row: MonthlyRow
    let currency: LoanCurrency

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppStrings.History.installmentTitle(row.k))
                        .font(.subheadline.weight(.semibold))
                    Text(UIDateSupport.displayDate(from: row.dueDate))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(AppStrings.Common.total)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(AppFormatting.currency(totalValue, currency: currency))
                        .font(.subheadline.weight(.bold))
                }
            }

            if !compositionSlices.isEmpty {
                HStack(alignment: .center, spacing: 14) {
                    InstallmentCompositionDonut(slices: compositionSlices, size: 58)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(compositionSlices) { slice in
                            BreakdownRow(title: slice.compactDisplayTitle, valueText: slice.formattedValue, color: slice.color)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Color.primary.opacity(0.02), in: .rect(cornerRadius: 14))
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }

    private var totalValue: Double {
        switch currency {
        case .uva:
            return row.cuotaUVA
        case .ars:
            return row.cuotaARS
        case .usd:
            return row.cuotaUSD
        }
    }

    private var compositionSlices: [InstallmentCompositionSlice] {
        guard let capital = row.capitalPartUVA, let interest = row.interestPartUVA else { return [] }
        return installmentCompositionSlices(
            capital: convertedValue(for: capital),
            interest: convertedValue(for: interest),
            insurance: row.insurancePartUVA.map(convertedValue(for:)),
            currency: currency
        )
    }

    private func convertedValue(for uvaAmount: Double) -> Double {
        amountInDisplayCurrency(uvaAmount: uvaAmount, currency: currency, uvaValue: row.uvaAtDay, usdValue: row.usdAtDay)
    }
}

struct AdvanceEditorView: View {
    let series: SeriesBundle
    let input: CaseInput
    let computed: CaseComputed
    let onSave: (CapitalAdvanceEvent) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = Date()
    @State private var amount = ""
    @State private var currency: LoanCurrency = .ars
    @State private var mode: AdvanceMode = .reduceTerm
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(AppStrings.AdvanceEditor.date, selection: $date, displayedComponents: .date)
                    TextField(AppStrings.AdvanceEditor.amount, text: $amount)
                        .keyboardType(.decimalPad)
                    Picker(AppStrings.Common.unitPicker, selection: $currency) {
                        ForEach(LoanCurrency.allCases) { item in
                            Label(item.displayName, systemImage: item == .uva ? "sum" : item == .ars ? "banknote" : "dollarsign")
                                .tag(item)
                        }
                    }
                    Picker(AppStrings.AdvanceEditor.effect, selection: $mode) {
                        ForEach(AdvanceMode.allCases) { item in
                            Label(item.title, systemImage: item == .reduceTerm ? "scissors" : "slider.horizontal.3")
                                .tag(item)
                        }
                    }
                } header: {
                    Label(AppStrings.AdvanceEditor.sectionTitle, systemImage: "arrow.down.circle.fill")
                } footer: {
                    Text(AppStrings.AdvanceEditor.footer)
                }

                if let previewText {
                    Section {
                        Label(previewText, systemImage: "sparkles")
                            .foregroundStyle(.primary)
                    } header: {
                        Text(AppStrings.AdvanceEditor.impact)
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(AppStrings.AdvanceEditor.navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppStrings.Common.save) {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var previewText: String? {
        let value = parseDecimal(amount)
        guard value > 0 else { return nil }

        let event = CapitalAdvanceEvent(
            dateISO: ISODateSupport.string(from: date),
            amount: value,
            currency: currency,
            mode: mode
        )

        let updatedEvents = [event]
        guard let recomputed = try? LoanCalculator.computeCase(input: input, series: series, events: updatedEvents) else {
            return nil
        }

        switch mode {
        case .reduceTerm:
            let savedMonths = max(0, computed.remainingMonths - recomputed.remainingMonths)
            return AppStrings.AdvanceEditor.reduceTermPreview(
                savings: formatRemainingTime(savedMonths),
                remaining: formatRemainingTime(recomputed.remainingMonths)
            )
        case .reduceInstallment:
            let newInstallmentUVA = recomputed.principalInstallmentUVA + (input.insuranceIncluded ? input.insuranceUVA : 0)
            let cutoffUVA = computed.cutoffUVA
            let cutoffUSD = (try? LoanCalculator.valueAtOrPrevious(dateISO: computed.cutoffDate, series: series.usd)) ?? 1
            let arsAmount = newInstallmentUVA * cutoffUVA
            let usdAmount = cutoffUSD > 0 ? arsAmount / cutoffUSD : 0
            return AppStrings.AdvanceEditor.reduceInstallmentPreview(
                uva: "\(AppFormatting.number(newInstallmentUVA, decimals: 2)) UVA",
                ars: AppFormatting.currency(arsAmount, currency: .ars),
                usd: AppFormatting.currency(usdAmount, currency: .usd)
            )
        }
    }

    private func save() {
        errorMessage = nil
        let numericAmount = parseDecimal(amount)

        guard numericAmount > 0 else {
            errorMessage = AppStrings.AdvanceEditor.invalidAmount
            AppAnalytics.shared.track(.advanceValidationFailed, properties: ["field": "amount"])
            return
        }

        onSave(
            CapitalAdvanceEvent(
                dateISO: ISODateSupport.string(from: date),
                amount: numericAmount,
                currency: currency,
                mode: mode
            )
        )
        dismiss()
    }

    private func parseDecimal(_ raw: String) -> Double {
        let normalized = raw.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }
}

struct MetricItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let symbol: String?
    let tint: Color
    let compact: Bool

    init(title: String, value: String, symbol: String? = nil, tint: Color, compact: Bool = false) {
        self.title = title
        self.value = value
        self.symbol = symbol
        self.tint = tint
        self.compact = compact
    }
}

struct MetricsGrid: View {
    let items: [MetricItem]

    private let columns = [
        GridItem(.flexible(minimum: 130), spacing: 10),
        GridItem(.flexible(minimum: 130), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: item.compact ? 8 : 10) {
                    if let symbol = item.symbol {
                        Label {
                            Text(item.title)
                                .font(item.compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        } icon: {
                            Image(systemName: symbol)
                                .font(item.compact ? .caption : .footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(item.title)
                            .font(item.compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Text(item.value)
                        .font(item.compact ? .headline : .title3.weight(.semibold))
                        .minimumScaleFactor(0.82)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(item.compact ? 12 : 14)
                .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: item.compact ? 16 : 18))
            }
        }
    }
}

struct BreakdownRow: View {
    let title: String
    let valueText: String
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text(valueText)
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct ProgressMetricRow: View {
    let title: String
    let value: Double
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(AppFormatting.percent(value, decimals: 0))
                    .font(.subheadline.weight(.semibold))
            }

            Gauge(value: value) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(.secondary)
                .scaleEffect(y: 1.15, anchor: .center)

            Text(caption)
                .font(.footnote)
                .foregroundStyle(Color.secondary.opacity(0.95))
        }
        .padding(13)
        .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 16))
    }
}

struct EmptySectionState: View {
    let title: String
    let subtitle: String
    let symbol: String
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 10 : 12) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 24 : 30, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(compact ? .headline : .title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(compact ? 20 : 24)
        .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: compact ? 18 : 20))
    }
}
