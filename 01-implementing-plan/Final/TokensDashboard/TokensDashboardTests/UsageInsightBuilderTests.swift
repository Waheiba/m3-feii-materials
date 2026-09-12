//
//  UsageInsightBuilderTests.swift
//  TokensDashboardTests
//

import Testing
import Foundation
@testable import TokensDashboard

struct UsageInsightBuilderTests {

  private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }

  private func period(
    year: Int,
    month: Int,
    startDay: Int,
    endYear: Int,
    endMonth: Int,
    endDay: Int,
    isComplete: Bool = true,
    totalTokens: Double,
    modelTokenTotals: [String: Double] = [:],
    calendar: Calendar? = nil
  ) -> UsageAggregatePeriod {
    let cal = calendar ?? utcCalendar()
    let start = DateComponents(calendar: cal, year: year, month: month, day: startDay).date!
    let end = DateComponents(calendar: cal, year: endYear, month: endMonth, day: endDay).date!
    return UsageAggregatePeriod(
      start: start,
      end: end,
      calendar: cal,
      isComplete: isComplete,
      totalTokens: totalTokens,
      modelTokenTotals: modelTokenTotals
    )
  }

  // MARK: - Period alignment and completeness

  @Test func adjacentEqualLengthCompletePeriodsAreValid() throws {
    let preceding = period(year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1, totalTokens: 2_000_000)
    let reporting = period(year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1, totalTokens: 2_000_000)
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    switch state {
    case .insufficientData: Issue.record("Expected a valid comparison, got insufficientData")
    default: break
    }
  }

  @Test func gapBetweenPeriodsIsInvalid() {
    let preceding = period(year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 3, endDay: 31, totalTokens: 2_000_000)
    let reporting = period(year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1, totalTokens: 2_000_000)
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    #expect(isInsufficientData(state))
  }

  @Test func unequalLengthPeriodsAreInvalid() {
    let preceding = period(year: 2026, month: 2, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1, totalTokens: 2_000_000)
    let reporting = period(year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1, totalTokens: 2_000_000)
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    #expect(isInsufficientData(state))
  }

  @Test func incompletePeriodIsInvalid() {
    let preceding = period(year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1, totalTokens: 2_000_000)
    let reporting = period(
      year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1,
      isComplete: false, totalTokens: 2_000_000
    )
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    #expect(isInsufficientData(state))
  }

  @Test func mismatchedTimeZoneIsInvalid() {
    var pst = Calendar(identifier: .gregorian)
    pst.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let preceding = period(year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1, totalTokens: 2_000_000)
    let reporting = period(year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1, totalTokens: 2_000_000, calendar: pst)
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    #expect(isInsufficientData(state))
  }

  // MARK: - Thresholds and boundaries (activity)

  @Test func activityChangeAtExactThresholdQualifies() {
    let preceding = period(year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1, totalTokens: 1_000_000)
    let reporting = period(year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1, totalTokens: 1_150_000)
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    #expect(insight(in: state, category: .activity) != nil)
  }

  @Test func activityChangeJustBelowThresholdDoesNotQualify() {
    let preceding = period(year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1, totalTokens: 1_000_000)
    let reporting = period(year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1, totalTokens: 1_149_000)
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    #expect(insight(in: state, category: .activity) == nil)
  }

  @Test func activityBelowMinimumVolumeIsUnavailable() {
    let preceding = period(year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1, totalTokens: 900_000)
    let reporting = period(year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1, totalTokens: 2_000_000)
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    #expect(unavailableCategories(in: state).contains(.activity))
  }

  // MARK: - Missing / invalid numeric values

  @Test func negativeTotalTokensIsInvalid() {
    let preceding = period(year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1, totalTokens: -1)
    let reporting = period(year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1, totalTokens: 2_000_000)
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    #expect(unavailableCategories(in: state).contains(.activity))
  }

  @Test func nonFiniteTotalTokensIsInvalid() {
    let preceding = period(year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1, totalTokens: .infinity)
    let reporting = period(year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1, totalTokens: 2_000_000)
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    #expect(unavailableCategories(in: state).contains(.activity))
  }

  @Test func zeroTotalTokensInEitherPeriodMakesModelMixUnavailable() {
    let preceding = period(year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1, totalTokens: 0)
    let reporting = period(year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1, totalTokens: 2_000_000)
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    #expect(unavailableCategories(in: state).contains(.modelMix))
  }

  // MARK: - Model mix: one-period-only models, ties, multiple shifts

  @Test func modelPresentInOnlyOnePeriodIsTreatedAsZero() {
    let preceding = period(
      year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1,
      totalTokens: 2_000_000, modelTokenTotals: ["Model A": 2_000_000]
    )
    let reporting = period(
      year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1,
      totalTokens: 2_000_000, modelTokenTotals: ["Model A": 1_600_000, "Model B": 400_000]
    )
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    // Model B: 0% -> 20% share = 20pp shift, larger than Model A's 20pp shift (equal); tie-break alphabetical -> Model A
    // Model A: 100% -> 80% = 20pp shift too. Tie -> alphabetically first name wins.
    let cardInsight = insight(in: state, category: .modelMix)
    #expect(cardInsight != nil)
    #expect(cardInsight?.title.contains("Model A") == true)
  }

  @Test func tiedShiftsBreakAlphabetically() {
    let preceding = period(
      year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1,
      totalTokens: 1_000_000, modelTokenTotals: ["Zeta": 500_000, "Alpha": 500_000]
    )
    let reporting = period(
      year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1,
      totalTokens: 1_000_000, modelTokenTotals: ["Zeta": 700_000, "Alpha": 300_000]
    )
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    let cardInsight = insight(in: state, category: .modelMix)
    #expect(cardInsight?.title.contains("Alpha") == true)
  }

  @Test func multipleShiftsSelectLargestAbsoluteShift() {
    let preceding = period(
      year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1,
      totalTokens: 1_000_000, modelTokenTotals: ["Small Shift": 500_000, "Big Shift": 500_000]
    )
    let reporting = period(
      year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1,
      totalTokens: 1_000_000, modelTokenTotals: ["Small Shift": 480_000, "Big Shift": 520_000]
    )
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    let cardInsight = insight(in: state, category: .modelMix)
    #expect(cardInsight?.title.contains("Big Shift") == true)
  }

  @Test func modelMixShiftBelowThresholdDoesNotQualify() {
    let preceding = period(
      year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1,
      totalTokens: 1_000_000, modelTokenTotals: ["Model A": 500_000]
    )
    let reporting = period(
      year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1,
      totalTokens: 1_000_000, modelTokenTotals: ["Model A": 540_000]
    )
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    #expect(insight(in: state, category: .modelMix) == nil)
  }

  // MARK: - Partial coverage and no-qualifying-change states

  @Test func validActivityWithUnavailableModelMixShowsCoverageNote() {
    let preceding = period(
      year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1,
      totalTokens: 1_000_000, modelTokenTotals: [:]
    )
    let reporting = period(
      year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1,
      totalTokens: 1_200_000, modelTokenTotals: [:]
    )
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    guard case .insights(let cards, let unavailable) = state else {
      Issue.record("Expected .insights state")
      return
    }
    #expect(cards.contains { $0.category == .activity })
    #expect(unavailable.contains(.modelMix))
  }

  @Test func allValidComparisonsBelowThresholdsReturnsNoQualifyingChanges() {
    let preceding = period(
      year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1,
      totalTokens: 1_000_000, modelTokenTotals: ["Model A": 500_000]
    )
    let reporting = period(
      year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1,
      totalTokens: 1_010_000, modelTokenTotals: ["Model A": 510_000]
    )
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    switch state {
    case .noQualifyingChanges:
      break
    default:
      Issue.record("Expected .noQualifyingChanges, got \(state)")
    }
  }

  @Test func noValidComparisonReturnsInsufficientData() {
    let preceding = period(year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1, totalTokens: -1)
    let reporting = period(year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1, totalTokens: 0)
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    #expect(isInsufficientData(state))
  }

  @Test func maximumCardCountCapsInsightsAtTwo() {
    let preceding = period(
      year: 2026, month: 3, startDay: 1, endYear: 2026, endMonth: 4, endDay: 1,
      totalTokens: 1_000_000, modelTokenTotals: ["Model A": 500_000]
    )
    let reporting = period(
      year: 2026, month: 4, startDay: 1, endYear: 2026, endMonth: 5, endDay: 1,
      totalTokens: 1_300_000, modelTokenTotals: ["Model A": 800_000]
    )
    let state = UsageInsightBuilder().build(precedingPeriod: preceding, reportingPeriod: reporting)
    guard case .insights(let cards, _) = state else {
      Issue.record("Expected .insights state")
      return
    }
    #expect(cards.count <= 2)
  }

  // MARK: - Helpers

  private func isInsufficientData(_ state: UsageInsightsState) -> Bool {
    switch state {
    case .insufficientData: return true
    default: return false
    }
  }

  private func insight(in state: UsageInsightsState, category: UsageInsightCategory) -> UsageInsight? {
    guard case .insights(let cards, _) = state else { return nil }
    return cards.first { $0.category == category }
  }

  private func unavailableCategories(in state: UsageInsightsState) -> [UsageInsightCategory] {
    switch state {
    case .insights(_, let unavailable): return unavailable
    case .noQualifyingChanges(let unavailable): return unavailable
    case .insufficientData: return UsageInsightCategory.allCases
    }
  }
}
