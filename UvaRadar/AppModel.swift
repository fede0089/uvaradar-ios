import Foundation
import Observation

@Observable
final class AppModel {
    private let seriesRepository: SeriesRepository
    private let casePersistence: CasePersistence

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

    init(seriesRepository: SeriesRepository, casePersistence: CasePersistence) {
        self.seriesRepository = seriesRepository
        self.casePersistence = casePersistence
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

        do {
            if let current = series {
                if let updated = try await seriesRepository.refreshSeries(ifNewerThan: current) {
                    series = updated
                    recomputeCase()
                    try persistCurrentCase()
                    showInlineMessage(AppStrings.Messages.quotesUpdated)
                } else if manual {
                    showInlineMessage(AppStrings.Messages.quotesAlreadyCurrent)
                }
            } else {
                let loaded = try await seriesRepository.fetchInitialSeries()
                series = loaded
                initialLoadRequired = false
                initialLoadError = nil
                recomputeCase()
                showInlineMessage(AppStrings.Messages.quotesLoaded)
            }
        } catch {
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
    }

    func cancelEditingCase() {
        isEditingCase = false
    }

    func saveCase(_ newInput: CaseInput) {
        input = newInput
        isEditingCase = false
        recomputeCase()
        try? persistCurrentCase()
    }

    func clearCase() {
        input = nil
        events = []
        computed = nil
        isEditingCase = true
        try? casePersistence.clear()
    }

    func addAdvance(_ event: CapitalAdvanceEvent) {
        events.append(event)
        events.sort { $0.dateISO < $1.dateISO }
        recomputeCase()
        try? persistCurrentCase()
    }

    func removeAdvance(_ eventID: UUID) {
        events.removeAll { $0.id == eventID }
        recomputeCase()
        try? persistCurrentCase()
    }

    private func bootstrap() async {
        isBootstrapping = true
        defer { isBootstrapping = false }

        restorePersistedCase()

        do {
            if let cached = try seriesRepository.loadCachedSeries() {
                series = cached
                initialLoadRequired = false
                initialLoadError = nil
                recomputeCase()
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
        } catch {
            initialLoadRequired = true
            initialLoadError = AppStrings.Messages.initialQuotesRequired
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
