/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.

import SwiftUI

// MARK: - Detail screen · AI Usage Insights

struct UsageInsightsView: View {
  private let usageInsightsViewModel = UsageInsightsViewModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 4) {
          Text(usageInsightsViewModel.periodLine)
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text(usageInsightsViewModel.cautionNote)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        VStack(spacing: 0) {
          ForEach(usageInsightsViewModel.insights) { insight in
            InsightCardRow(insight: insight)
            Divider()
          }
        }
      }
      .padding(24)
    }
    .background(Color(.systemBackground))
    .navigationTitle("AI Usage Insights")
    .toolbarTitleDisplayMode(.inline)
  }
}

private struct InsightCardRow: View {
  let insight: UsageInsight

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text(insight.category.label.uppercased())
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(insight.severity.label)
          .font(.caption.weight(.semibold))
      }
      Text(insight.title)
        .font(.system(.title3, design: .serif, weight: .semibold))
      Text(insight.metric)
        .font(.subheadline.weight(.medium))
      Text(insight.explanation)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Text("Suggested next step: \(insight.suggestedNextStep)")
        .font(.footnote)
      Text(insight.caveat)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .italic()
    }
    .padding(.vertical, 18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  private var accessibilityLabel: String {
    "\(insight.category.label), \(insight.severity.label). \(insight.title). \(insight.metric). \(insight.explanation) Suggested next step: \(insight.suggestedNextStep) \(insight.caveat)"
  }
}

#Preview("Details · AI Usage Insights") {
  NavigationStack {
    UsageInsightsView()
  }
}
