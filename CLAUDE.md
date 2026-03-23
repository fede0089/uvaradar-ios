# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a pure Xcode project with no build automation scripts. Use the **Xcode MCP** tools (never `xcodebuild` CLI):

1. Get the `tabIdentifier` with `mcp__xcode__XcodeListWindows`
2. Build: `mcp__xcode__BuildProject` (pass `tabIdentifier`)
3. Run all tests: `mcp__xcode__RunAllTests` (pass `tabIdentifier`)
4. Run specific tests: `mcp__xcode__GetTestList` to discover tests, then `mcp__xcode__RunSomeTests`
5. Inspect build errors: `mcp__xcode__GetBuildLog` (pass `tabIdentifier`)

No CocoaPods, Swift Package Manager, Fastlane, or linting tools are configured.

## Architecture

**UvaRadar** is a SwiftUI app for tracking Argentine UVA-indexed mortgage loans (UVA = Unidad de Valor Adquisitivo, a daily-adjusted inflation unit).

### State Management

Uses the iOS 17+ `@Observable` macro pattern — no Combine. A single `AppModel` class holds all app state and is injected at the root via `.environment()`. Views read properties directly; mutations go through `AppModel` methods.

### Data Flow

```
Network (SeriesRepository) ──► AppModel ──► Views
Disk (CasePersistence)     ──►           (auto-refresh via @Observable)
User Input (LoanEditorView) ──►
```

- **Series data** (UVA/USD daily quotes) fetched from `https://uva-radar.vercel.app` and cached to disk at `series-cache-v1.json`. Manifest is checked first; full data only fetched when newer quotes exist. Auto-refresh is throttled to 5-minute intervals.
- **Case state** (user's loan parameters + capital advance events) persisted to `case-state-v1.json`.
- On launch: load cached series → show UI → refresh in background.

### Calculation Engine

`LoanMath.swift` — pure stateless financial formulas (annuity, remaining balance, rate conversions).

`LoanCalculator` (inside `LoanMath.swift`) — orchestrates the full calculation:
1. Converts original amount to UVA using quote on grant date
2. Generates amortization schedule (French method)
3. Applies any `CapitalAdvanceEvent`s chronologically, recalculating from the advance date forward
4. Produces `CaseComputed` with full `MonthlyRow` history

`DebtCostEstimator.swift` — estimates effective annual cost using 90-day UVA growth rate.

### Key Files

| File | Responsibility |
|------|---------------|
| `AppModel.swift` | Single source of truth; orchestrates fetch, persist, compute |
| `Models.swift` | All data types: `CaseInput`, `SeriesBundle`, `MonthlyRow`, `CaseComputed`, `CapitalAdvanceEvent` |
| `SeriesRepository.swift` | Network + disk caching for UVA/USD quote series |
| `CasePersistence.swift` | JSON persistence of user's loan case |
| `LoanMath.swift` | All financial math and amortization logic |
| `ContentView.swift` | Root navigation; switches between loading/error/dashboard states |
| `DashboardView.swift` | Main UI: balance, payment history, charts, capital advances |
| `LoanEditorView.swift` | Form for creating/editing a loan case |
| `AppStrings.swift` | All user-facing strings in Spanish (es_AR) and English |

### Domain Concepts

- **UVA** — the daily-adjusted inflation unit; all loan calculations are done in UVA internally, then converted to ARS or USD for display
- **TNA** — Tasa Nominal Anual (annual nominal rate); entered as a percentage (e.g., `30` = 30%)
- **Capital Advance** — an extra payment that either reduces remaining term or reduces monthly installment amount (`AdvanceMode`)
- **French amortization** — fixed nominal installment in UVA; real ARS value changes daily with UVA rate

### Concurrency

All Swift actors default to `@MainActor` (set via `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` in build settings). Network calls are `async/await`. UVA + USD data files are fetched in parallel using `async let`.

### Localization

`AppStrings.swift` contains all strings as nested enums. The active language is controlled by `AppLanguage` (default: Spanish). Use `localized("ES", "EN")` helper for new strings — do not hardcode display text elsewhere.
