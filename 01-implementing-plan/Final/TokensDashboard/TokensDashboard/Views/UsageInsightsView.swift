/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.

import SwiftUI

// MARK: - Detail screen · AI usage insights

struct UsageInsightsView: View {
  private let viewModel = UsageInsightsViewModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text(viewModel.helperText)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        content
      }
      .padding(24)
    }
    .background(Color(.systemBackground))
    .navigationTitle("AI Usage Insights")
    .toolbarTitleDisplayMode(.inline)
  }

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .insights(let cards, let unavailable):
      VStack(spacing: 0) {
        ForEach(cards) { card in
          InsightCard(insight: card)
          Divider()
        }
      }
      if !unavailable.isEmpty {
        CoverageNote(unavailableCategories: unavailable)
      }

    case .noQualifyingChanges(let unavailable):
      InformationalState(message: "No changes met the current review thresholds for this period.")
      if !unavailable.isEmpty {
        CoverageNote(unavailableCategories: unavailable)
      }

    case .insufficientData:
      InformationalState(message: "There isn’t enough data to compare this reporting period yet.")
    }
  }
}

// MARK: - Card

private struct InsightCard: View {
  let insight: UsageInsight

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(insight.title)
          .font(.system(.title3, design: .serif, weight: .semibold))
        Spacer(minLength: 0)
        if let trendDirection = insight.trendDirection {
          Image(systemName: trendDirection == .increased ? "arrow.up" : "arrow.down")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
      }
      Text(insight.evidence)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Text(insight.reviewPrompt)
        .font(.subheadline.weight(.medium))
      Text(insight.periodLabel)
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(insight.category.displayName). \(insight.evidence) \(insight.reviewPrompt) \(insight.periodLabel)."
    )
  }
}

// MARK: - Informational states

private struct InformationalState: View {
  let message: String

  var body: some View {
    Text(message)
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 18)
      .accessibilityElement(children: .combine)
  }
}

private struct CoverageNote: View {
  let unavailableCategories: [UsageInsightCategory]

  var body: some View {
    Text("Comparison unavailable for \(unavailableCategories.map(\.displayName).joined(separator: " and ")) this period.")
      .font(.caption)
      .foregroundStyle(.tertiary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 4)
      .accessibilityElement(children: .combine)
  }
}

// MARK: - Previews

#Preview("AI Usage Insights") {
  NavigationStack {
    UsageInsightsView()
  }
}
