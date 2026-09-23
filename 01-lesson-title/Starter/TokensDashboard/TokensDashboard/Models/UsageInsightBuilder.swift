/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import Foundation

struct UsageInsightBuilder {
  struct Configuration {
    var minimumComparisonVolume: Double = 1_000_000
    var minimumGroupSize: Int = 10
    var activityThreshold: Double = 0.15
    var modelMixThreshold: Double = 0.10
  }

  let configuration: Configuration

  init(configuration: Configuration = Configuration()) {
    self.configuration = configuration
  }

  func build(reportingPeriod: AIUsagePeriod, precedingPeriod: AIUsagePeriod) -> UsageInsightsState {
    let activityResult = buildActivityInsight(
      reportingPeriod: reportingPeriod,
      precedingPeriod: precedingPeriod
    )
    let modelMixResult = buildModelMixInsight(
      reportingPeriod: reportingPeriod,
      precedingPeriod: precedingPeriod
    )

    let activityValid = activityResult.isValid
    let modelMixValid = modelMixResult.isValid

    // Neither category valid -> insufficientData
    if !activityValid && !modelMixValid {
      return .insufficientData
    }

    var qualifyingCards: [UsageInsight] = []
    var unavailableCategories: Set<UsageInsightCategory> = []

    if activityValid {
      if let card = activityResult.card {
        qualifyingCards.append(card)
      }
    } else {
      unavailableCategories.insert(.activity)
    }

    if modelMixValid {
      if let card = modelMixResult.card {
        qualifyingCards.append(card)
      }
    } else {
      unavailableCategories.insert(.modelMix)
    }

    // At least one card qualifies -> .insights
    if !qualifyingCards.isEmpty {
      return .insights(cards: qualifyingCards, unavailableCategories: unavailableCategories)
    }

    // No card qualifies: if every category was validly comparable -> noQualifyingChanges,
    // otherwise (some category was unavailable) -> insufficientData.
    if unavailableCategories.isEmpty {
      return .noQualifyingChanges
    } else {
      return .insufficientData
    }
  }

  // MARK: - Private helpers

  private struct InsightResult {
    let isValid: Bool
    let card: UsageInsight?
  }

  private func buildActivityInsight(
    reportingPeriod: AIUsagePeriod,
    precedingPeriod: AIUsagePeriod
  ) -> InsightResult {
    guard
      reportingPeriod.isComplete,
      precedingPeriod.isComplete,
      reportingPeriod.contributorCount >= configuration.minimumGroupSize,
      precedingPeriod.contributorCount >= configuration.minimumGroupSize,
      reportingPeriod.totalTokens.isFinite, reportingPeriod.totalTokens >= 0,
      precedingPeriod.totalTokens.isFinite, precedingPeriod.totalTokens >= 0,
      reportingPeriod.totalTokens >= configuration.minimumComparisonVolume,
      precedingPeriod.totalTokens >= configuration.minimumComparisonVolume
    else {
      return InsightResult(isValid: false, card: nil)
    }

    let relativeChange = (reportingPeriod.totalTokens - precedingPeriod.totalTokens)
      / precedingPeriod.totalTokens

    guard abs(relativeChange) >= configuration.activityThreshold else {
      return InsightResult(isValid: true, card: nil)
    }

    let percentDisplay = Int((abs(relativeChange) * 100).rounded())
    let direction: UsageInsightTrendDirection = relativeChange > 0 ? .increased : .decreased
    let changeWord = relativeChange > 0 ? "increased" : "decreased"
    let evidence =
      "Team token activity \(changeWord) \(percentDisplay)% compared with the prior period."

    let card = UsageInsight(
      category: .activity,
      title: "AI Activity",
      evidence: evidence,
      reviewPrompt: "Review this alongside the team's current work.",
      reportingPeriodLabel: periodLabel(
        reportingPeriod: reportingPeriod,
        precedingPeriod: precedingPeriod
      ),
      trendDirection: direction
    )
    return InsightResult(isValid: true, card: card)
  }

  private func buildModelMixInsight(
    reportingPeriod: AIUsagePeriod,
    precedingPeriod: AIUsagePeriod
  ) -> InsightResult {
    guard
      reportingPeriod.isComplete,
      precedingPeriod.isComplete,
      reportingPeriod.contributorCount >= configuration.minimumGroupSize,
      precedingPeriod.contributorCount >= configuration.minimumGroupSize,
      reportingPeriod.totalTokens.isFinite, reportingPeriod.totalTokens > 0,
      precedingPeriod.totalTokens.isFinite, precedingPeriod.totalTokens > 0,
      reportingPeriod.tokensByModel.values.allSatisfy({ $0.isFinite && $0 >= 0 }),
      precedingPeriod.tokensByModel.values.allSatisfy({ $0.isFinite && $0 >= 0 })
    else {
      return InsightResult(isValid: false, card: nil)
    }

    let allModels = Set(reportingPeriod.tokensByModel.keys)
      .union(precedingPeriod.tokensByModel.keys)

    // Find the model with the largest abs(shift); break ties alphabetically.
    var bestModel: String? = nil
    var bestAbsShift: Double = -1
    var bestShift: Double = 0

    for model in allModels.sorted() {
      let shareReporting = (reportingPeriod.tokensByModel[model] ?? 0)
        / reportingPeriod.totalTokens
      let sharePreceding = (precedingPeriod.tokensByModel[model] ?? 0)
        / precedingPeriod.totalTokens
      let shift = shareReporting - sharePreceding
      let absShift = abs(shift)

      if absShift > bestAbsShift {
        bestAbsShift = absShift
        bestShift = shift
        bestModel = model
      }
      // Ties: already visiting in sorted order so first alphabetically wins.
    }

    guard let selectedModel = bestModel,
          bestAbsShift >= configuration.modelMixThreshold else {
      return InsightResult(isValid: true, card: nil)
    }

    let pointsDisplay = Int((bestAbsShift * 100).rounded())
    let direction: UsageInsightTrendDirection = bestShift > 0 ? .increased : .decreased
    let changeWord = bestShift > 0 ? "increased" : "decreased"
    let evidence =
      "\(selectedModel)'s share of team token activity \(changeWord) by \(pointsDisplay) percentage points this period."

    let card = UsageInsight(
      category: .modelMix,
      title: "Model Mix",
      evidence: evidence,
      reviewPrompt: "Review whether this reflects the team's current work.",
      reportingPeriodLabel: periodLabel(
        reportingPeriod: reportingPeriod,
        precedingPeriod: precedingPeriod
      ),
      trendDirection: direction
    )
    return InsightResult(isValid: true, card: card)
  }

  /// Produces a human-readable label such as "Apr 1–30, 2026 vs. Mar 1–31, 2026".
  private func periodLabel(
    reportingPeriod: AIUsagePeriod,
    precedingPeriod: AIUsagePeriod
  ) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")

    func rangeString(start: Date, end: Date) -> String {
      let calendar = Calendar.current
      let startComponents = calendar.dateComponents([.month, .day, .year], from: start)
      let endComponents = calendar.dateComponents([.month, .day, .year], from: end)

      formatter.dateFormat = "MMM d"
      let startStr = formatter.string(from: start)

      if startComponents.month == endComponents.month
          && startComponents.year == endComponents.year {
        formatter.dateFormat = "d, yyyy"
        let endStr = formatter.string(from: end)
        return "\(startStr)\u{2013}\(endStr)"
      } else {
        formatter.dateFormat = "MMM d, yyyy"
        let endStr = formatter.string(from: end)
        return "\(startStr)\u{2013}\(endStr)"
      }
    }

    let reportingStr = rangeString(
      start: reportingPeriod.start,
      end: reportingPeriod.end
    )
    let precedingStr = rangeString(
      start: precedingPeriod.start,
      end: precedingPeriod.end
    )
    return "\(reportingStr) vs. \(precedingStr)"
  }
}
