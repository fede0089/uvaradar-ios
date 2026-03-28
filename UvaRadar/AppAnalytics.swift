import AmplitudeUnified
import Foundation

protocol AnalyticsTracking {
    func track(_ event: AppAnalytics.Event, properties: [String: Any]?)
    func syncUserState(input: CaseInput?, events: [CapitalAdvanceEvent])
}

final class AppAnalytics: AnalyticsTracking {
    enum Event: String {
        case appBootstrapStarted = "app_bootstrap_started"
        case appBootstrapCompleted = "app_bootstrap_completed"
        case quotesRefreshRequested = "quotes_refresh_requested"
        case quotesRefreshSucceeded = "quotes_refresh_succeeded"
        case quotesRefreshFailed = "quotes_refresh_failed"
        case caseEditStarted = "case_edit_started"
        case caseSaved = "case_saved"
        case caseCleared = "case_cleared"
        case advanceEditorOpened = "advance_editor_opened"
        case advanceAdded = "advance_added"
        case advanceRemoved = "advance_removed"
        case loanFormValidationFailed = "loan_form_validation_failed"
        case advanceValidationFailed = "advance_validation_failed"
        case paymentHistoryOpened = "payment_history_opened"
    }

    static let shared = AppAnalytics()

    private let amplitude: Amplitude

    private init() { 
        let analyticsConfig = AnalyticsConfig(
            autocapture: [.sessions, .appLifecycles, .screenViews]
        )

        // Conservative masking keeps session replay useful while reducing exposure of financial text.
        let sessionReplayConfig = SessionReplayPlugin.Config(
            sampleRate: 1.0,
            maskLevel: .conservative
        )

        amplitude = Amplitude(
            apiKey: "99ac16abd0d58bf5cb4735a70fbc02dc",
            analyticsConfig: analyticsConfig,
            sessionReplayConfig: sessionReplayConfig
        )

        amplitude.identify(userProperties: [
            "app_name": "UvaRadar",
            "app_platform": "iOS"
        ])
    }

    func track(_ event: Event, properties: [String: Any]? = nil) {
        amplitude.track(eventType: event.rawValue, eventProperties: sanitized(properties))
    }

    func syncUserState(input: CaseInput?, events: [CapitalAdvanceEvent]) {
        var properties: [String: Any] = [
            "has_saved_case": input != nil,
            "advance_count": events.count
        ]

        if let input {
            properties["insurance_included"] = input.insuranceIncluded
            properties["original_currency"] = input.originalCurrency.rawValue
            properties["loan_term_months"] = input.totalMonths
        } else {
            properties["insurance_included"] = false
            properties["original_currency"] = "NONE"
            properties["loan_term_months"] = 0
        }

        amplitude.identify(userProperties: properties)
    }

    private func sanitized(_ properties: [String: Any]?) -> [String: Any]? {
        guard let properties, !properties.isEmpty else { return nil }
        return properties
    }
}
