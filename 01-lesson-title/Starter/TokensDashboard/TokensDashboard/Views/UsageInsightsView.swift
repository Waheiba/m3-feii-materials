/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import SwiftUI

// MARK: - Usage Insights screen

struct UsageInsightsView: View {
    private let viewModel = UsageInsightsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Title + subtitle
                VStack(alignment: .leading, spacing: 6) {
                    Text("AI Usage Insights")
                        .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    Text(viewModel.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)

                // MARK: Caution banner
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(viewModel.caution)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(12)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Caution: \(viewModel.caution)")
                .padding(.bottom, 20)

                // MARK: Insight cards
                VStack(spacing: 12) {
                    ForEach(viewModel.insights) { insight in
                        InsightCard(insight: insight)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .background(Color(.systemBackground))
        .navigationTitle("AI Usage Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - InsightCard

private struct InsightCard: View {
    let insight: UsageInsight

    private var severityColor: Color {
        switch insight.severity {
        case .informational: return .secondary
        case .review:        return .indigo
        case .watch:         return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Top row: category + severity badge
            HStack {
                Text(insight.category.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(insight.severity.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(severityColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(severityColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            // Title
            Text(insight.title)
                .font(.headline)

            // Metric
            Text(insight.metric)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Color.indigo)

            // Explanation
            Text(insight.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Next step
            VStack(alignment: .leading, spacing: 2) {
                Text("Next step")
                    .font(.caption.weight(.semibold))
                Text(insight.nextStep)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Caveat
            Text(insight.caveat)
                .font(.caption)
                .italic()
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(insight.category.rawValue) \(insight.severity.rawValue) \(insight.title) \(insight.metric) \(insight.explanation) \(insight.nextStep) \(insight.caveat)"
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        UsageInsightsView()
    }
}
