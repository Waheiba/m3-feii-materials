/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import Foundation

// MARK: - Category and trend

enum UsageInsightCategory: String, CaseIterable, Hashable {
  case activity
  case modelMix
}

enum UsageInsightTrendDirection {
  case increased
  case decreased
}

// MARK: - Display model

/// Aggregate, display-ready summary for one insight category.
/// Must never contain individual names/IDs, ticket titles, prompt content,
/// cohort labels, or cost/price data — it is aggregate and display-ready only.
struct UsageInsight: Identifiable {
  let category: UsageInsightCategory
  let title: String
  let evidence: String
  let reviewPrompt: String
  let reportingPeriodLabel: String
  let trendDirection: UsageInsightTrendDirection?
  var id: UsageInsightCategory { category }
}

// MARK: - State

/// Outcome of attempting to build UsageInsight cards for a reporting period pair.
///
/// - `insufficientData`: no category (activity or modelMix) could form a valid
///   comparison at all for the two periods. Also used for the edge case where one
///   category is validly comparable but does not cross its threshold while the
///   other category cannot be compared at all (i.e. whenever zero cards would be
///   shown AND not every category was validly comparable), since there is nothing
///   to display and coverage was incomplete.
///
/// - `noQualifyingChanges`: every category was validly comparable, but none
///   crossed its qualification threshold. Reserved strictly for the case where
///   ALL categories had a valid comparison.
///
/// - `insights(cards:unavailableCategories:)`: one or two categories qualified.
///   `cards` is ordered activity-then-modelMix. `unavailableCategories` lists
///   ONLY categories whose comparison could not be validly formed at all (used to
///   render a neutral partial-coverage note) — it must NOT include a category
///   that was validly compared but simply did not cross its threshold (that case
///   is silently omitted with no note).
enum UsageInsightsState {
  case insights(cards: [UsageInsight], unavailableCategories: Set<UsageInsightCategory>)
  case noQualifyingChanges
  case insufficientData
}
