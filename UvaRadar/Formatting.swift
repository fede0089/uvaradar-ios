import Foundation

enum AppFormatting {
    static func number(_ value: Double, decimals: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(decimals)f", value)
    }

    static func currency(_ value: Double, currency: LoanCurrency) -> String {
        if currency == .uva {
            return "\(number(value, decimals: 2)) UVA"
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func percent(_ value: Double, decimals: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "es_AR")
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: value)) ?? "\(value * 100)%"
    }
}

func amountInDisplayCurrency(uvaAmount: Double, currency: LoanCurrency, uvaValue: Double, usdValue: Double) -> Double {
    switch currency {
    case .uva:
        return uvaAmount
    case .ars:
        return uvaAmount * uvaValue
    case .usd:
        guard usdValue != 0 else { return 0 }
        return (uvaAmount * uvaValue) / usdValue
    }
}
