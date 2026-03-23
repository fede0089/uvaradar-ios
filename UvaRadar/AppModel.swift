import Foundation
import Observation

@Observable
final class AppModel {
    private let seriesRepository: SeriesRepository
    private let casePersistence: CasePersistence
    private let analytics: AnalyticsTracking

    private var didStart = false
    private var lastRefreshAttemptAt: Date?

    var series: SeriesBundle?
    var input: CaseInput?
    var events: [CapitalAdvanceEvent] = []
    var computed: CaseComputed?

    var isBootstrapping = false
    var isRefreshing = false
    var initialLoadRequired = false
    var initialLoadError: String?
    var inlineMessage: String?
    var isEditingCase = false

    init(seriesRepository: SeriesRepository, casePersistence: CasePersistence, analytics: AnalyticsTracking) {
        self.seriesRepository = seriesRepository
        self.casePersistence = casePersistence
        self.analytics = analytics
    }

    var lastUpdateDateText: String {
        guard let date = series?.manifest.lastCloseDate else { return AppStrings.Common.noData }
        return UIDateSupport.displayDate(from: date)
    }

    var hasLocalData: Bool {
        series != nil
    }

    var debtCostEstimate: DebtCostEstimate? {
        guard let input, let series else { return nil }
        return DebtCostEstimator.estimate(series: series, input: input)
    }

    func startIfNeeded() async {
        guard !didStart else { return }
        didStart = true
        await bootstrap()
    }

    func refreshFromForegroundIfNeeded() async {
        guard hasLocalData else { return }
        guard shouldAttemptAutomaticRefresh() else { return }
        await refresh(manual: false)
    }

    func refresh(manual: Bool) async {
        guard !isRefreshing else { return }
        lastRefreshAttemptAt = Date()
        isRefreshing = true
        defer { isRefreshing = false }

        analytics.track(.quotesRefreshRequested, properties: [
            "manual": manual,
            "has_current_series": series != nil
        ])

        do {
            if let current = series {
                if let updated = try await seriesRepository.refreshSeries(ifNewerThan: current) {
                    series = updated
                    recomputeCase()
                    try persistCurrentCase()
                    showInlineMessage(AppStrings.Messages.quotesUpdated)
                    analytics.track(.quotesRefreshSucceeded, properties: [
                        "manual": manual,
                        "updated": true
                    ])
                } else if manual {
                    showInlineMessage(AppStrings.Messages.quotesAlreadyCurrent)
                    analytics.track(.quotesRefreshSucceeded, properties: [
                        "manual": true,
                        "updated": false
                    ])
                }
            } else {
                let loaded = try await seriesRepository.fetchInitialSeries()
                series = loaded
                initialLoadRequired = false
                initialLoadError = nil
                recomputeCase()
                showInlineMessage(AppStrings.Messages.quotesLoaded)
                analytics.track(.quotesRefreshSucceeded, properties: [
                    "manual": manual,
                    "updated": true,
                    "initial_load": true
                ])
            }
        } catch {
            analytics.track(.quotesRefreshFailed, properties: [
                "manual": manual,
                "has_current_series": series != nil
            ])
            if series == nil {
                initialLoadRequired = true
                initialLoadError = AppStrings.Messages.initialQuotesRequired
            } else if manual {
                showInlineMessage(error.localizedDescription)
            }
        }
    }

    func beginEditingCase() {
        isEditingCase = true
        analytics.track(.caseEditStarted, properties: [
            "has_existing_case": input != nil
        ])
    }

    func cancelEditingCase() {
        isEditingCase = false
    }

    func saveCase(_ newInput: CaseInput) {
        let mode = input == nil ? "create" : "edit"
        input = newInput
        isEditingCase = false
        recomputeCase()
        try? persistCurrentCase()
        analytics.syncUserState(input: input, events: events)
        analytics.track(.caseSaved, properties: [
            "mode": mode,
            "original_currency": newInput.originalCurrency.rawValue,
            "insurance_included": newInput.insuranceIncluded,
            "loan_term_months": newInput.totalMonths
        ])
    }

    func clearCase() {
        let previousAdvanceCount = events.count
        input = nil
        events = []
        computed = nil
        isEditingCase = true
        try? casePersistence.clear()
        analytics.syncUserState(input: input, events: events)
        analytics.track(.caseCleared, properties: [
            "previous_advance_count": previousAdvanceCount
        ])
    }

    func addAdvance(_ event: CapitalAdvanceEvent) {
        events.append(event)
        events.sort { $0.dateISO < $1.dateISO }
        recomputeCase()
        try? persistCurrentCase()
        analytics.syncUserState(input: input, events: events)
        analytics.track(.advanceAdded, properties: [
            "mode": event.mode.rawValue,
            "currency": event.currency.rawValue,
            "advance_count": events.count
        ])
    }

    func removeAdvance(_ eventID: UUID) {
        events.removeAll { $0.id == eventID }
        recomputeCase()
        try? persistCurrentCase()
        analytics.syncUserState(input: input, events: events)
        analytics.track(.advanceRemoved, properties: [
            "advance_count": events.count
        ])
    }

    private func bootstrap() async {
        isBootstrapping = true
        defer { isBootstrapping = false }

        analytics.track(.appBootstrapStarted, properties: nil)

        restorePersistedCase()
        analytics.syncUserState(input: input, events: events)

        do {
            if let cached = try seriesRepository.loadCachedSeries() {
                series = cached
                initialLoadRequired = false
                initialLoadError = nil
                recomputeCase()
                analytics.track(.appBootstrapCompleted, properties: [
                    "series_source": "cache",
                    "has_saved_case": input != nil
                ])
                await refresh(manual: false)
                return
            }
        } catch {
            initialLoadError = error.localizedDescription
        }

        do {
            let downloaded = try await seriesRepository.fetchInitialSeries()
            series = downloaded
            initialLoadRequired = false
            initialLoadError = nil
            recomputeCase()
            analytics.track(.appBootstrapCompleted, properties: [
                "series_source": "network",
                "has_saved_case": input != nil
            ])
        } catch {
            initialLoadRequired = true
            initialLoadError = AppStrings.Messages.initialQuotesRequired
            analytics.track(.appBootstrapCompleted, properties: [
                "series_source": "unavailable",
                "has_saved_case": input != nil
            ])
        }
    }

    private func restorePersistedCase() {
        guard let payload = try? casePersistence.load() else { return }
        input = payload.input
        events = payload.events
        isEditingCase = payload.input == nil
    }

    private func recomputeCase() {
        guard let input, let series else {
            computed = nil
            return
        }

        do {
            computed = try LoanCalculator.computeCase(input: input, series: series, events: events)
        } catch {
            computed = nil
            showInlineMessage(error.localizedDescription)
        }
    }

    private func persistCurrentCase() throws {
        try casePersistence.save(input: input, events: events)
    }

    private func shouldAttemptAutomaticRefresh() -> Bool {
        guard let lastRefreshAttemptAt else { return true }
        return Date().timeIntervalSince(lastRefreshAttemptAt) > 60 * 5
    }

    private func showInlineMessage(_ message: String) {
        inlineMessage = message

        Task {
            try? await Task.sleep(for: .seconds(3))
            if inlineMessage == message {
                inlineMessage = nil
            }
        }
    }
}
