/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.

import Foundation

// MARK: - Model layer

/// The review area a usage insight speaks to.
enum InsightCategory {
  case modelConcentration
  case modelUsageIncrease
  case deliveryTrend
  case dataQuality

  var label: String {
    switch self {
    case .modelConcentration: return "Model concentration"
    case .modelUsageIncrease: return "Model usage increase"
    case .deliveryTrend: return "Delivery trend"
    case .dataQuality: return "Data quality"
    }
  }
}

/// How urgently a usage insight is worth a human look. Never communicated
/// through color alone — every card also speaks this label aloud.
enum InsightSeverity: String {
  case informational
  case review
  case watch

  var label: String {
    switch self {
    case .informational: return "Informational"
    case .review: return "Review"
    case .watch: return "Watch"
    }
  }
}

/// A single team-level review signal surfaced by `UsageInsightsService`.
/// Insights are review prompts, not automatic conclusions — every insight
/// carries its own caveat alongside the explanation and suggested next step.
struct UsageInsight: Identifiable {
  let category: InsightCategory
  let severity: InsightSeverity
  let title: String
  let metric: String
  let explanation: String
  let suggestedNextStep: String
  let caveat: String

  var id: String { "\(category.label)·\(title)" }
}
