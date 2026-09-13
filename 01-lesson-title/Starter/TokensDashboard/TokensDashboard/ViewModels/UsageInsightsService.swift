/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.

import Foundation

// MARK: - Service layer

/// Generates team-level `UsageInsight`s from the app's existing mock stores
/// using deterministic local rules. No LLM call, no networking — insights
/// are review prompts, not automatic conclusions.
struct UsageInsightsService {
  private let costStore: ModelCostStore
  private let ticketToMergeStore: TicketToMergeStore

  init(
    costStore: ModelCostStore = ModelCostStore(),
    ticketToMergeStore: TicketToMergeStore = TicketToMergeStore()
  ) {
    self.costStore = costStore
    self.ticketToMergeStore = ticketToMergeStore
  }

  func generateInsights() -> [UsageInsight] {
    let insights = [
      modelConcentrationInsight(),
      modelUsageIncreaseInsight(),
      deliveryTrendInsight(),
    ].compactMap { $0 }

    if insights.isEmpty {
      return [dataQualityInsight()]
    }
    return insights
  }

  // MARK: Rules

  /// Fires when the top model accounts for more than 40% of month-to-date spend.
  private func modelConcentrationInsight() -> UsageInsight? {
    let spend = costStore.monthToDateSpend
    guard spend > 0, let topModel = costStore.modelCosts.max(by: { $0.cost < $1.cost }) else {
      return nil
    }
    let share = topModel.cost / spend
    guard share > 0.4 else { return nil }
    return UsageInsight(
      category: .modelConcentration,
      severity: .review,
      title: "\(topModel.name) is concentrating spend",
      metric: "\(KPIFormat.percent(share)) of month-to-date spend",
      explanation: "One model accounts for more than 40% of this month's spend, which increases exposure if that model changes price, availability, or capability.",
      suggestedNextStep: "Review routing policy and confirm this concentration is intentional.",
      caveat: "Concentration alone does not mean the spend is misused — task mix and model fit also drive this share."
    )
  }

  /// Fires when any model has a month-over-month increase above 15%.
  private func modelUsageIncreaseInsight() -> UsageInsight? {
    guard let fastestGrowing = costStore.modelCosts.max(by: { $0.change < $1.change }),
          fastestGrowing.change > 0.15 else {
      return nil
    }
    return UsageInsight(
      category: .modelUsageIncrease,
      severity: .watch,
      title: "\(fastestGrowing.name) usage is rising quickly",
      metric: "\(KPIFormat.signedPercent(fastestGrowing.change)) month over month",
      explanation: "This model's spend grew more than 15% versus last month, which is worth understanding before it becomes the new baseline.",
      suggestedNextStep: "Check whether the increase matches a known project ramp-up or a shift in default model choice.",
      caveat: "A single month of growth does not establish a trend on its own."
    )
  }

  /// Fires when the AI-heavy cohort's ticket-to-merge trend improves
  /// meaningfully (more than 10%) over the trailing period.
  private func deliveryTrendInsight() -> UsageInsight? {
    let heavySeries = ticketToMergeStore.samples
      .filter { $0.cohort == .heavyUsers }
      .sorted { $0.month < $1.month }
    guard let first = heavySeries.first, let latest = heavySeries.last,
          first.month != latest.month, first.avgDays > 0 else {
      return nil
    }
    let improvement = (first.avgDays - latest.avgDays) / first.avgDays
    guard improvement > 0.1 else { return nil }
    return UsageInsight(
      category: .deliveryTrend,
      severity: .informational,
      title: "Heavy AI users are merging tickets faster",
      metric: "\(KPIFormat.percent(improvement)) faster since \(first.month.formatted(.dateTime.month(.wide)))",
      explanation: "Average ticket-to-merge time for the heavy AI usage cohort has trended down over the trailing period.",
      suggestedNextStep: "Compare against the light-usage cohort and recent task complexity before adjusting team guidance.",
      caveat: "This is a correlation, not evidence that AI usage caused the improvement — task mix, staffing, and process changes can all contribute."
    )
  }

  /// Cautious fallback shown when the required inputs are empty, stale, or
  /// otherwise too thin to support any of the rules above.
  private func dataQualityInsight() -> UsageInsight {
    UsageInsight(
      category: .dataQuality,
      severity: .informational,
      title: "Not enough data for a review signal",
      metric: "No qualifying signals this period",
      explanation: "Model spend and ticket-to-merge data did not meet the minimum thresholds needed to surface a review signal this month.",
      suggestedNextStep: "Check back once more month-to-date data is available.",
      caveat: "An empty result is not a conclusion about team performance."
    )
  }
}
