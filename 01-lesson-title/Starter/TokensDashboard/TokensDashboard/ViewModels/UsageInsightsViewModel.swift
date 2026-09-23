/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

struct UsageInsightsViewModel {
  let state: UsageInsightsState

  init(periodStore: AIUsagePeriodStore = AIUsagePeriodStore(), builder: UsageInsightBuilder = UsageInsightBuilder()) {
    state = builder.build(reportingPeriod: periodStore.reportingPeriod, precedingPeriod: periodStore.precedingPeriod)
  }

  init(state: UsageInsightsState) {
    self.state = state
  }
}
