import Foundation

enum UvaTerminology {
    static var capitalPending: String { AppStrings.Terminology.capitalPending }
    static var capitalAmortization: String { AppStrings.Terminology.capitalAmortization }
    static var interest: String { AppStrings.Terminology.interest }
    static var nextInstallment: String { AppStrings.Terminology.nextInstallment }
    static var remainingTerm: String { AppStrings.Terminology.remainingTerm }
    static var advances: String { AppStrings.Terminology.advances }
    static var installmentHistory: String { AppStrings.Terminology.installmentHistory }
    static var uvaIntro: String { AppStrings.Terminology.uvaIntro }

    static func currencyContext(for currency: LoanCurrency) -> String? {
        AppStrings.Terminology.currencyContext(for: currency)
    }

    static func originalAmountContext(for currency: LoanCurrency) -> String? {
        AppStrings.Terminology.originalAmountContext(for: currency)
    }
}
