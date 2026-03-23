import SwiftUI

struct LoanEditorView: View {
    let existingInput: CaseInput?
    let series: SeriesBundle
    let onSave: (CaseInput) -> Void
    let onCancel: () -> Void

    @State private var grantDate: Date
    @State private var firstDueDate: Date
    @State private var totalMonths: String
    @State private var tnaPercent: String
    @State private var originalAmount: String
    @State private var originalCurrency: LoanCurrency
    @State private var insuranceIncluded: Bool
    @State private var insuranceUVA: String
    @State private var validationMessage: String?

    init(existingInput: CaseInput?, series: SeriesBundle, onSave: @escaping (CaseInput) -> Void, onCancel: @escaping () -> Void) {
        self.existingInput = existingInput
        self.series = series
        self.onSave = onSave
        self.onCancel = onCancel

        let currentGrant = existingInput?.grantDate.flatMap { ISODateSupport.parse($0) } ?? Date()
        let currentFirstDue = ISODateSupport.parse(existingInput?.firstDueDate ?? "") ?? Date()

        _grantDate = State(initialValue: currentGrant)
        _firstDueDate = State(initialValue: currentFirstDue)
        _totalMonths = State(initialValue: existingInput.map { String($0.totalMonths) } ?? "")
        _tnaPercent = State(initialValue: existingInput.map { AppFormatting.number($0.tna * 100, decimals: 2) } ?? "")
        _originalAmount = State(initialValue: existingInput.map { AppFormatting.number($0.originalAmount, decimals: 2) } ?? "")
        _originalCurrency = State(initialValue: existingInput?.originalCurrency ?? .uva)
        _insuranceIncluded = State(initialValue: existingInput?.insuranceIncluded ?? false)
        _insuranceUVA = State(initialValue: existingInput.map { AppFormatting.number($0.insuranceUVA, decimals: 2) } ?? "")
    }

    private var formTitle: String {
        existingInput == nil ? AppStrings.LoanEditor.createTitle : AppStrings.LoanEditor.editTitle
    }

    private var formSubtitle: String {
        existingInput == nil
            ? AppStrings.LoanEditor.createSubtitle
            : AppStrings.LoanEditor.editSubtitle
    }

    private var conversionPreview: String? {
        let amount = parseDecimal(originalAmount)
        guard amount > 0 else { return nil }

        let baseDate = ISODateSupport.string(from: grantDate)

        guard let uvaValue = try? LoanCalculator.valueAtOrPrevious(dateISO: baseDate, series: series.uva),
              let usdValue = try? LoanCalculator.valueAtOrPrevious(dateISO: baseDate, series: series.usd)
        else {
            return nil
        }

        let uva: Double
        let ars: Double
        let usd: Double

        switch originalCurrency {
        case .uva:
            uva = amount
            ars = amount * uvaValue
            usd = ars / usdValue
        case .ars:
            ars = amount
            uva = amount / uvaValue
            usd = amount / usdValue
        case .usd:
            usd = amount
            ars = amount * usdValue
            uva = ars / uvaValue
        }

        let baseText = AppStrings.LoanEditor.conversionPreview(
            uva: AppFormatting.number(uva, decimals: 2),
            ars: AppFormatting.currency(ars, currency: .ars),
            usd: AppFormatting.currency(usd, currency: .usd)
        )

        if let context = UvaTerminology.originalAmountContext(for: originalCurrency) {
            return "\(baseText) \(context)"
        }

        return baseText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerBlock
            loanDataCard
            financeCard
            insuranceCard

            if let validationMessage {
                MessageCard(text: validationMessage, accent: .red, symbol: "exclamationmark.triangle.fill")
            }

            ViewThatFits {
                HStack(spacing: 12) {
                    secondaryActions
                    primaryAction
                }
                VStack(spacing: 12) {
                    primaryAction
                    secondaryActions
                }
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formTitle)
                .font(.title3.weight(.semibold))

            Text(formSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(AppStrings.Content.dataStatusTitle(UIDateSupport.displayDate(from: series.manifest.lastCloseDate)))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var loanDataCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    title: AppStrings.LoanEditor.originSectionTitle,
                    subtitle: AppStrings.LoanEditor.originSectionSubtitle,
                    symbol: "calendar",
                    tint: .secondary
                )

                ViewThatFits {
                    HStack(spacing: 12) {
                        inputDateRow(title: AppStrings.Dashboard.grantDate, date: $grantDate)
                        inputDateRow(title: AppStrings.Dashboard.firstDueDate, date: $firstDueDate)
                    }

                    VStack(spacing: 12) {
                        inputDateRow(title: AppStrings.Dashboard.grantDate, date: $grantDate)
                        inputDateRow(title: AppStrings.Dashboard.firstDueDate, date: $firstDueDate)
                    }
                }

                EditorField(
                    title: AppStrings.LoanEditor.originalTermTitle,
                    caption: AppStrings.LoanEditor.originalTermCaption,
                    symbol: "hourglass",
                    text: $totalMonths,
                    keyboardType: .numberPad,
                    trailingText: AppStrings.Common.monthsUnit
                )
            }
        }
    }

    private var financeCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    title: AppStrings.LoanEditor.financeSectionTitle,
                    subtitle: AppStrings.LoanEditor.financeSectionSubtitle,
                    symbol: "banknote",
                    tint: .secondary
                )

                EditorField(
                    title: AppStrings.Dashboard.nominalAnnualRate,
                    caption: AppStrings.LoanEditor.tnaCaption,
                    symbol: "percent",
                    text: $tnaPercent,
                    keyboardType: .decimalPad,
                    trailingText: "%"
                )

                EditorField(
                    title: AppStrings.Dashboard.originalAmount,
                    caption: AppStrings.LoanEditor.originalAmountCaption,
                    symbol: "banknote",
                    text: $originalAmount,
                    keyboardType: .decimalPad,
                    trailingText: originalCurrency.displayName
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text(AppStrings.LoanEditor.amountInputUnitTitle)
                        .font(.subheadline.weight(.semibold))
                    Picker(AppStrings.Common.unitPicker, selection: $originalCurrency) {
                        ForEach(LoanCurrency.allCases) { currency in
                            Text(currency.displayName).tag(currency)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let conversionPreview {
                    MessageCard(text: conversionPreview, accent: .secondary, symbol: "arrow.left.arrow.right.circle.fill")
                }
            }
        }
    }

    private var insuranceCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(
                    title: AppStrings.LoanEditor.insuranceSectionTitle,
                    subtitle: AppStrings.LoanEditor.insuranceSectionSubtitle,
                    symbol: "shield",
                    tint: .secondary
                )

                Toggle(isOn: $insuranceIncluded) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppStrings.LoanEditor.includeInsurance)
                            .font(.subheadline.weight(.semibold))
                        Text(AppStrings.LoanEditor.includeInsuranceSubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                if insuranceIncluded {
                    EditorField(
                        title: AppStrings.LoanEditor.includedInsuranceTitle,
                        caption: AppStrings.LoanEditor.includedInsuranceCaption,
                        symbol: "shield.checkered",
                        text: $insuranceUVA,
                        keyboardType: .decimalPad,
                        trailingText: "UVA"
                    )
                }
            }
        }
    }

    private var primaryAction: some View {
        Button(existingInput == nil ? AppStrings.LoanEditor.saveLoan : AppStrings.LoanEditor.updateLoan) {
            save()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    @ViewBuilder
    private var secondaryActions: some View {
        if existingInput != nil {
            Button(AppStrings.Common.cancel, action: onCancel)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }

    private func inputDateRow(title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            DatePicker(title, selection: date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 16))
    }

    private func save() {
        validationMessage = nil

        let months = Int(totalMonths) ?? 0
        let tna = parseDecimal(tnaPercent) / 100
        let amount = parseDecimal(originalAmount)
        let insuranceAmount = parseDecimal(insuranceUVA)

        guard months >= 1, months <= 600 else {
            validationMessage = AppStrings.LoanEditor.invalidTerm
            return
        }
        guard tna >= 0, tna <= 1 else {
            validationMessage = AppStrings.LoanEditor.invalidRate
            return
        }
        guard amount > 0 else {
            validationMessage = AppStrings.LoanEditor.invalidAmount
            return
        }
        if insuranceIncluded, insuranceAmount <= 0 {
            validationMessage = AppStrings.LoanEditor.invalidInsurance
            return
        }

        let payload = CaseInput(
            grantDate: ISODateSupport.string(from: grantDate),
            firstDueDate: ISODateSupport.string(from: firstDueDate),
            totalMonths: months,
            tna: tna,
            originalAmount: amount,
            originalCurrency: originalCurrency,
            insuranceIncluded: insuranceIncluded,
            insuranceUVA: insuranceIncluded ? insuranceAmount : 0
        )

        onSave(payload)
    }

    private func parseDecimal(_ raw: String) -> Double {
        let normalized = raw.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }
}

private struct EditorField: View {
    let title: String
    let caption: String
    let symbol: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let trailingText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if !caption.isEmpty {
                        Text(caption)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 10) {
                TextField(title, text: $text)
                    .keyboardType(keyboardType)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.medium))

                if let trailingText {
                    Text(trailingText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 16))
        }
    }
}
