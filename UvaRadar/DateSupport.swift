import Foundation

enum ISODateSupport {
    nonisolated static let timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    nonisolated static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()

    nonisolated static func makeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    nonisolated static func parse(_ iso: String) -> Date? {
        makeFormatter().date(from: iso)
    }

    nonisolated static func string(from date: Date) -> String {
        makeFormatter().string(from: date)
    }

    nonisolated static func addMonths(_ months: Int, to iso: String) -> String? {
        guard let date = parse(iso),
              let next = calendar.date(byAdding: .month, value: months, to: date)
        else {
            return nil
        }

        return string(from: next)
    }

    nonisolated static func addDays(_ days: Int, to iso: String) -> String? {
        guard let date = parse(iso),
              let next = calendar.date(byAdding: .day, value: days, to: date)
        else {
            return nil
        }

        return string(from: next)
    }
}

enum UIDateSupport {
    nonisolated static func makeDisplayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppStrings.localeIdentifier)
        formatter.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }

    nonisolated static func displayDate(from iso: String) -> String {
        guard let date = ISODateSupport.parse(iso) else { return iso }
        return makeDisplayFormatter().string(from: date)
    }

    nonisolated static func displayMonthYear(from iso: String) -> String {
        guard let date = ISODateSupport.parse(iso) else { return iso }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppStrings.localeIdentifier)
        formatter.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")
        formatter.dateFormat = "MM/yyyy"
        return formatter.string(from: date)
    }

    nonisolated static func chartMonthYear(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppStrings.localeIdentifier)
        formatter.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")
        formatter.dateFormat = "LLL yy"
        return formatter.string(from: date).lowercased()
    }
}

func generateDueDates(firstDueISO: String, count: Int) -> [String] {
    guard count > 0 else { return [] }

    return (0..<count).compactMap { index in
        ISODateSupport.addMonths(index, to: firstDueISO)
    }
}

func formatRemainingTime(_ remainingMonths: Int) -> String {
    let years = remainingMonths / 12
    let months = remainingMonths % 12
    return AppStrings.Common.remainingTime(years: years, months: months)
}

func formatRemainingTimeCompact(_ remainingMonths: Int) -> String {
    let years = remainingMonths / 12
    let months = remainingMonths % 12
    return AppStrings.Common.remainingTimeCompact(years: years, months: months)
}
