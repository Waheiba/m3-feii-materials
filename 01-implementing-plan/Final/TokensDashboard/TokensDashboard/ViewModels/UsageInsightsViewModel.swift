/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.

import Foundation

// MARK: - Insight rule layer

/// Pure, deterministic rules over aggregate period data only. Never accepts
/// developer records, identity fields, ticket data, or cohort data, and
/// never performs networking, persistence, or LLM calls.
struct UsageInsightBuilder {
  struct Configuration {
    var minimumComparisonVolume: Double = 1_000_000
    var activityRelativeChangeThreshold: Double = 0.15
    var modelMixShiftThresholdPercentagePoints: Double = 10
    var maximumCardCount: Int = 2
  }

  let configuration: Configuration

  init(configuration: Configuration = Configuration()) {
    self.configuration = configuration
  }

  func build(precedingPeriod: UsageAggregatePeriod, reportingPeriod: UsageAggregatePeriod) -> UsageInsightsState {
    guard periodsFormValidComparison(preceding: precedingPeriod, reporting: reportingPeriod) else {
      return .insufficientData
    }

    let label = periodLabel(preceding: precedingPeriod, reporting: reportingPeriod)
    let activity = activityComparison(preceding: precedingPeriod, reporting: reportingPeriod)
    let modelMix = modelMixComparison(preceding: precedingPeriod, reporting: reportingPeriod)

    var cards: [UsageInsight] = []
    var unavailable: [UsageInsightCategory] = []

    if let activity {
      if let card = qualifyingInsight(for: activity, periodLabel: label) {
        cards.append(card)
      }
    } else {
      unavailable.append(.activity)
    }

    if let modelMix {
      if let card = qualifyingInsight(for: modelMix, periodLabel: label) {
        cards.append(card)
      }
    } else {
      unavailable.append(.modelMix)
    }

    guard unavailable.count < UsageInsightCategory.allCases.count else { return .insufficientData }

    if cards.isEmpty {
      return .noQualifyingChanges(unavailableCategories: unavailable)
    }

    return .insights(Array(cards.prefix(configuration.maximumCardCount)), unavailableCategories: unavailable)
  }

  // MARK: - Period validity

  private func periodsFormValidComparison(preceding: UsageAggregatePeriod, reporting: UsageAggregatePeriod) -> Bool {
    guard preceding.isComplete, reporting.isComplete,
          preceding.start < preceding.end, reporting.start < reporting.end,
          preceding.end == reporting.start,
          preceding.calendar.timeZone == reporting.calendar.timeZone
    else { return false }

    let precedingDays = preceding.calendar.dateComponents([.day], from: preceding.start, to: preceding.end).day
    let reportingDays = reporting.calendar.dateComponents([.day], from: reporting.start, to: reporting.end).day
    return precedingDays != nil && precedingDays == reportingDays
  }

  private func periodLabel(preceding: UsageAggregatePeriod, reporting: UsageAggregatePeriod) -> String {
    "\(monthYear(reporting)) vs. \(monthYear(preceding))"
  }

  private func monthYear(_ period: UsageAggregatePeriod) -> String {
    var style = Date.FormatStyle.dateTime.month(.wide).year()
    style.calendar = period.calendar
    style.timeZone = period.calendar.timeZone
    return period.start.formatted(style)
  }

  // MARK: - AI activity

  private struct ActivityComparison {
    let precedingTotal: Double
    let reportingTotal: Double
    var relativeChange: Double { (reportingTotal - precedingTotal) / precedingTotal }
  }

  private func activityComparison(preceding: UsageAggregatePeriod, reporting: UsageAggregatePeriod) -> ActivityComparison? {
    guard preceding.totalTokens.isFinite, reporting.totalTokens.isFinite,
          preceding.totalTokens >= 0, reporting.totalTokens >= 0,
          preceding.totalTokens >= configuration.minimumComparisonVolume,
          reporting.totalTokens >= configuration.minimumComparisonVolume
    else { return nil }
    return ActivityComparison(precedingTotal: preceding.totalTokens, reportingTotal: reporting.totalTokens)
  }

  // MARK: - Model mix

  private struct ModelMixComparison {
    let modelName: String
    let precedingShare: Double
    let reportingShare: Double
    var absoluteShiftPercentagePoints: Double { abs(reportingShare - precedingShare) * 100 }
  }

  private func modelMixComparison(preceding: UsageAggregatePeriod, reporting: UsageAggregatePeriod) -> ModelMixComparison? {
    guard preceding.totalTokens.isFinite, reporting.totalTokens.isFinite,
          preceding.totalTokens > 0, reporting.totalTokens > 0
    else { return nil }

    let modelNames = Set(preceding.modelTokenTotals.keys).union(reporting.modelTokenTotals.keys)
    guard !modelNames.isEmpty else { return nil }

    var best: ModelMixComparison?
    for name in modelNames {
      let precedingTokens = preceding.modelTokenTotals[name] ?? 0
      let reportingTokens = reporting.modelTokenTotals[name] ?? 0
      guard precedingTokens.isFinite, reportingTokens.isFinite,
            precedingTokens >= 0, reportingTokens >= 0
      else { return nil }

      let candidate = ModelMixComparison(
        modelName: name,
        precedingShare: precedingTokens / preceding.totalTokens,
        reportingShare: reportingTokens / reporting.totalTokens
      )

      if let current = best {
        if candidate.absoluteShiftPercentagePoints > current.absoluteShiftPercentagePoints
          || (candidate.absoluteShiftPercentagePoints == current.absoluteShiftPercentagePoints && candidate.modelName < current.modelName) {
          best = candidate
        }
      } else {
        best = candidate
      }
    }
    return best
  }

  // MARK: - Card assembly

  private func qualifyingInsight(for activity: ActivityComparison, periodLabel: String) -> UsageInsight? {
    guard abs(activity.relativeChange) >= configuration.activityRelativeChangeThreshold else { return nil }
    let changeDisplay = KPIFormat.percent(abs(activity.relativeChange))
    let direction: UsageInsightTrendDirection = activity.relativeChange >= 0 ? .increased : .decreased
    let verb = direction == .increased ? "increased" : "decreased"
    return UsageInsight(
      category: .activity,
      title: "Team AI activity \(verb)",
      evidence: "Team token activity \(verb) \(changeDisplay) compared with the prior period.",
      reviewPrompt: "Review this alongside the team’s current work.",
      periodLabel: periodLabel,
      trendDirection: direction
    )
  }

  private func qualifyingInsight(for modelMix: ModelMixComparison, periodLabel: String) -> UsageInsight? {
    guard modelMix.absoluteShiftPercentagePoints >= configuration.modelMixShiftThresholdPercentagePoints else { return nil }
    let direction: UsageInsightTrendDirection = modelMix.reportingShare >= modelMix.precedingShare ? .increased : .decreased
    let verb = direction == .increased ? "increased" : "decreased"
    let pointsDisplay = Int(modelMix.absoluteShiftPercentagePoints.rounded())
    return UsageInsight(
      category: .modelMix,
      title: "\(modelMix.modelName)’s share \(verb)",
      evidence: "\(modelMix.modelName)’s share of team token activity \(verb) by \(pointsDisplay) percentage points this period.",
      reviewPrompt: "Review whether this reflects the team’s current work.",
      periodLabel: periodLabel,
      trendDirection: direction
    )
  }
}

// MARK: - Detail view model

struct UsageInsightsViewModel {
  let helperText = "These are team-level review prompts, not performance judgments. Use them to inform planning and retrospective conversations."
  let state: UsageInsightsState

  init(
    periodStore: UsageAggregatePeriodStore = UsageAggregatePeriodStore(),
    builder: UsageInsightBuilder = UsageInsightBuilder()
  ) {
    state = builder.build(precedingPeriod: periodStore.precedingPeriod, reportingPeriod: periodStore.reportingPeriod)
  }
}
