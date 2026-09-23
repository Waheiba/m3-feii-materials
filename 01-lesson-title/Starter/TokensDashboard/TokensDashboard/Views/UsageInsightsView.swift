/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import SwiftUI

// MARK: - Usage insights screen

struct UsageInsightsView: View {
  private let viewModel: UsageInsightsViewModel

  init() {
    viewModel = UsageInsightsViewModel()
  }

  init(viewModel: UsageInsightsViewModel) {
    self.viewModel = viewModel
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Text("These are team-level review prompts for planning and retrospective conversations — not individual performance measures.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .padding(.top, 16)
          .padding(.bottom, 20)

        stateContent
      }
      .padding(.horizontal, 24)
    }
    .background(Color(.systemBackground))
    .navigationTitle("AI Usage Insights")
    .toolbarTitleDisplayMode(.inline)
  }

  @ViewBuilder
  private var stateContent: some View {
    switch viewModel.state {
    case .insights(let cards, let unavailableCategories):
      ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
        if index > 0 {
          Divider()
        }
        InsightCardView(insight: card)
      }
      if !unavailableCategories.isEmpty {
        Divider()
        coverageNote(for: unavailableCategories)
      }

    case .noQualifyingChanges:
      Text("No changes met the current review thresholds for this period.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.vertical, 16)

    case .insufficientData:
      Text("There isn't enough comparable activity this period to show AI usage insights.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.vertical, 16)
    }
  }

  @ViewBuilder
  private func coverageNote(for unavailableCategories: Set<UsageInsightCategory>) -> some View {
    let lines = unavailableCategories.sorted(by: { $0.rawValue < $1.rawValue }).map { category -> String in
      switch category {
      case .activity: return "Activity could not be compared for this period."
      case .modelMix: return "Model mix could not be compared for this period."
      }
    }
    VStack(alignment: .leading, spacing: 4) {
      ForEach(lines, id: \.self) { line in
        Text(line)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 12)
  }
}

// MARK: - Card view

private struct InsightCardView: View {
  let insight: UsageInsight

  private var trendIconName: String? {
    switch insight.trendDirection {
    case .increased: return "arrow.up"
    case .decreased: return "arrow.down"
    case nil: return nil
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(insight.title)
          .font(.system(.title2, design: .serif, weight: .semibold))
        if let iconName = trendIconName {
          Image(systemName: iconName)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
      }
      Text(insight.evidence)
        .font(.body)
      Text(insight.reportingPeriodLabel)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(insight.reviewPrompt)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(insight.category.rawValue.capitalized): \(insight.evidence). \(insight.reportingPeriodLabel). \(insight.reviewPrompt)")
  }
}

// MARK: - Previews

#Preview("AI Usage Insights · Default") {
  NavigationStack {
    UsageInsightsView()
  }
}

#Preview("AI Usage Insights · One Card + Coverage Note") {
  let card = UsageInsight(
    category: .activity,
    title: "Activity increased",
    evidence: "AI-assisted requests increased 42% compared to the prior period.",
    reviewPrompt: "What drove the increase — new workflows, a specific project, or broader adoption?",
    reportingPeriodLabel: "Jun 1 – Jun 30 vs May 1 – May 31",
    trendDirection: .increased
  )
  NavigationStack {
    UsageInsightsView(viewModel: UsageInsightsViewModel(state: .insights(
      cards: [card],
      unavailableCategories: [.modelMix]
    )))
  }
}

#Preview("AI Usage Insights · No Qualifying Changes") {
  NavigationStack {
    UsageInsightsView(viewModel: UsageInsightsViewModel(state: .noQualifyingChanges))
  }
}

#Preview("AI Usage Insights · Insufficient Data") {
  NavigationStack {
    UsageInsightsView(viewModel: UsageInsightsViewModel(state: .insufficientData))
  }
}
