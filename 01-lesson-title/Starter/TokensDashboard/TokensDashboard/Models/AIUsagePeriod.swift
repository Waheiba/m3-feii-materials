/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import Foundation

/// Aggregate token-usage data for a single reporting period.
/// Contains no cost-derived values -- tokens only.
/// contributorCount is a headcount aggregate that enforces a privacy floor;
/// never break it down by individual.
struct AIUsagePeriod {
  let start: Date
  let end: Date
  let isComplete: Bool
  /// Aggregate headcount for the period; never broken down by individual.
  let contributorCount: Int
  let totalTokens: Double
  /// Keys are stable model-identifier display strings.
  let tokensByModel: [String: Double]
}

// MARK: - Data source

/// Source of truth for two consecutive calendar-month usage periods, anchored
/// to `DashboardStartDate.today` so every screen shows the same numbers.
struct AIUsagePeriodStore {
  let reportingPeriod: AIUsagePeriod
  let precedingPeriod: AIUsagePeriod

  init() {
    let calendar = Calendar.current
    let anchor = DashboardStartDate.today

    // reportingPeriod: the full calendar month immediately before the anchor
    // (April 1-30, 2026 when anchor is 2026-05-01).
    let reportingStart = calendar.date(
      from: calendar.dateComponents([.year, .month],
        from: calendar.date(byAdding: .month, value: -1, to: anchor)!))!
    let reportingEnd = calendar.date(byAdding: .day, value: -1,
      to: calendar.date(byAdding: .month, value: 1, to: reportingStart)!)!

    reportingPeriod = AIUsagePeriod(
      start: reportingStart,
      end: reportingEnd,
      isComplete: true,
      contributorCount: 42,
      totalTokens: 50_000_000,
      tokensByModel: [
        "Claude Opus 4.8":  22_500_000,
        "Claude Sonnet 4.6": 15_000_000,
        "Claude Haiku 4.5":   7_500_000,
        "GPT-5 Codex":        3_500_000,
        "Gemini 3 Pro":       1_500_000,
      ]
    )

    // precedingPeriod: the calendar month before reportingPeriod
    // (March 1-31, 2026 when anchor is 2026-05-01).
    let precedingStart = calendar.date(
      from: calendar.dateComponents([.year, .month],
        from: calendar.date(byAdding: .month, value: -2, to: anchor)!))!
    let precedingEnd = calendar.date(byAdding: .day, value: -1,
      to: calendar.date(byAdding: .month, value: 1, to: precedingStart)!)!

    precedingPeriod = AIUsagePeriod(
      start: precedingStart,
      end: precedingEnd,
      isComplete: true,
      contributorCount: 42,
      totalTokens: 40_000_000,
      tokensByModel: [
        "Claude Opus 4.8":  12_000_000,
        "Claude Sonnet 4.6": 16_000_000,
        "Claude Haiku 4.5":   8_000_000,
        "GPT-5 Codex":        3_000_000,
        "Gemini 3 Pro":       1_000_000,
      ]
    )
  }
}
