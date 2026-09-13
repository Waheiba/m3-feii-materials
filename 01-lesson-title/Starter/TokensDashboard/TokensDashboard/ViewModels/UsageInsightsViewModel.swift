/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.

import Foundation

// MARK: - Detail view model

struct UsageInsightsViewModel {
  let periodLine = DashboardStartDate.today.formatted(.dateTime.month(.wide).year()) + " · Team-level review signals"
  let cautionNote = "These insights are review prompts, not automatic conclusions. Interpret token usage alongside task complexity, quality, and delivery context."
  let insights: [UsageInsight]

  var isDataQualityOnly: Bool {
    insights.count == 1 && insights.first?.category == .dataQuality
  }

  init(service: UsageInsightsService = UsageInsightsService()) {
    insights = service.generateInsights()
  }
}
