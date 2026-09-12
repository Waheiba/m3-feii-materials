/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.

import Foundation

// MARK: - Model layer

/// An aggregate, team-level token usage period. Contains no individual,
/// ticket, prompt, cohort, or cost data — only totals over a fixed window.
struct UsageAggregatePeriod {
  let start: Date
  let end: Date
  /// Reporting calendar, including its time zone convention.
  let calendar: Calendar
  let isComplete: Bool
  let totalTokens: Double
  /// Aggregate token totals keyed by stable model identifier.
  let modelTokenTotals: [String: Double]
}

// MARK: - Data source

/// Source of truth for AI Usage Insights: two adjacent, equal-length,
/// completed periods as of `DashboardStartDate.today` (May 1, 2026) — the
/// most recently completed period and the one immediately preceding it.
/// Periods use a fixed UTC calendar so period length is unambiguous and
/// unaffected by daylight-saving transitions.
struct UsageAggregatePeriodStore {
  let precedingPeriod: UsageAggregatePeriod
  let reportingPeriod: UsageAggregatePeriod

  init() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!

    let precedingStart = DateComponents(calendar: calendar, year: 2026, month: 3, day: 2).date!
    let reportingStart = DateComponents(calendar: calendar, year: 2026, month: 4, day: 1).date!
    let reportingEnd = DateComponents(calendar: calendar, year: 2026, month: 5, day: 1).date!

    precedingPeriod = UsageAggregatePeriod(
      start: precedingStart,
      end: reportingStart,
      calendar: calendar,
      isComplete: true,
      totalTokens: 28_000_000,
      modelTokenTotals: [
        "Claude Opus 4.8": 9_000_000,
        "Claude Sonnet 4.6": 10_000_000,
        "Claude Haiku 4.5": 6_000_000,
        "GPT-5 Codex": 2_000_000,
        "Gemini 3 Pro": 1_000_000,
      ]
    )

    reportingPeriod = UsageAggregatePeriod(
      start: reportingStart,
      end: reportingEnd,
      calendar: calendar,
      isComplete: true,
      totalTokens: 33_000_000,
      modelTokenTotals: [
        "Claude Opus 4.8": 14_000_000,
        "Claude Sonnet 4.6": 10_500_000,
        "Claude Haiku 4.5": 5_500_000,
        "GPT-5 Codex": 2_000_000,
        "Gemini 3 Pro": 1_000_000,
      ]
    )
  }
}
