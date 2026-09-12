/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.

import Foundation

// MARK: - Model layer

/// Closed set of team-level usage categories the insight builder can evaluate.
enum UsageInsightCategory: String, CaseIterable, Identifiable {
  case activity
  case modelMix

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .activity: "AI activity"
    case .modelMix: "model mix"
    }
  }
}

/// Display-only direction, supplementary to the card's text. Never the sole
/// carrier of meaning — text must convey the same information.
enum UsageInsightTrendDirection {
  case increased
  case decreased
}

/// A single team-level review-prompt card. Contains no individual, ticket,
/// prompt, cohort, or cost data.
struct UsageInsight: Identifiable {
  let category: UsageInsightCategory
  let title: String
  let evidence: String
  let reviewPrompt: String
  let periodLabel: String
  let trendDirection: UsageInsightTrendDirection?

  var id: UsageInsightCategory { category }
}

/// What `UsageInsightsView` renders: qualifying cards, or one of two
/// informational states that are distinct from each other and from an error.
enum UsageInsightsState {
  /// One or two qualifying cards, in stable category order. `unavailableCategories`
  /// lists categories that could not be compared, for a neutral coverage note.
  case insights([UsageInsight], unavailableCategories: [UsageInsightCategory])
  /// At least one category had a valid comparison, but none met its threshold.
  /// `unavailableCategories` lists any category that could not be compared,
  /// for a neutral coverage note alongside the no-qualifying-changes message.
  case noQualifyingChanges(unavailableCategories: [UsageInsightCategory])
  /// No category has a valid comparison for the current reporting period.
  case insufficientData
}
