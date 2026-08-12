/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import Foundation

struct UsageInsightsViewModel {

    // MARK: - Stored Properties

    let insights: [UsageInsight]
    let screenTitle: String
    let subtitle: String
    let caution: String
    let summaryRowDetail: String

    // MARK: - Init

    init(service: UsageInsightsService = UsageInsightsService()) {
        let generatedInsights = service.generateInsights()
        self.insights = generatedInsights

        self.screenTitle = "AI Usage Insights"

        self.caution = "These insights are review prompts, not automatic conclusions. Interpret token usage alongside task complexity, quality, and delivery context."

        let monthYear = UsageInsightsViewModel.formattedMonthYear(from: DashboardStartDate.today)

        self.subtitle = "\(monthYear) · Team-level review signals"

        let actionableCount = generatedInsights
            .filter { $0.category != .dataQuality && $0.category != .noSignal }
            .count

        if actionableCount == 0 {
            self.summaryRowDetail = "No team-level review signals were flagged for \(monthYear). Open AI Usage Insights for details."
        } else {
            let signalWord = actionableCount == 1 ? "signal" : "signals"
            self.summaryRowDetail = "\(actionableCount) team-level review \(signalWord) found for \(monthYear). Review model concentration, token investment, and delivery trends before changing team guidance."
        }
    }

    // MARK: - Helpers

    private static func formattedMonthYear(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
