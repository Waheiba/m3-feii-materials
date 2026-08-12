/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import Foundation

// MARK: - Service

/// Pure, synchronous business-rules engine that reads from the three mock
/// stores and emits a list of team-level insights.  No networking, no async,
/// no side effects.
struct UsageInsightsService {

    let costStore: ModelCostStore
    let outcomeStore: DeveloperOutcomeStore
    let ticketToMergeStore: TicketToMergeStore

    init(
        costStore: ModelCostStore = ModelCostStore(),
        outcomeStore: DeveloperOutcomeStore = DeveloperOutcomeStore(),
        ticketToMergeStore: TicketToMergeStore = TicketToMergeStore()
    ) {
        self.costStore = costStore
        self.outcomeStore = outcomeStore
        self.ticketToMergeStore = ticketToMergeStore
    }

    // MARK: - Public API

    func generateInsights() -> [UsageInsight] {
        // Rule 5 — data-quality guardrail: bail early if any store is empty.
        if costStore.modelCosts.isEmpty
            || outcomeStore.developerOutcomes.isEmpty
            || ticketToMergeStore.samples.isEmpty {
            return [dataQualityInsight()]
        }

        var insights: [UsageInsight] = []

        if let insight = modelConcentrationInsight() { insights.append(insight) }
        if let insight = modelIncreaseInsight()      { insights.append(insight) }
        if let insight = deliveryTrendInsight()      { insights.append(insight) }
        if let insight = workflowPatternInsight()    { insights.append(insight) }

        return insights
    }

    // MARK: - Rule 1: Model Concentration

    /// Triggers when the highest-cost model exceeds 40 % of total spend.
    private func modelConcentrationInsight() -> UsageInsight? {
        let totalSpend = costStore.monthToDateSpend
        guard totalSpend > 0,
              let topModel = costStore.modelCosts.max(by: { $0.cost < $1.cost }),
              topModel.cost > 0
        else { return nil }

        let share = topModel.cost / totalSpend
        guard share > 0.40, share <= 1.0 else { return nil }

        return UsageInsight(
            category: .modelConcentration,
            severity: .review,
            title: "Spend Concentrated in One Model",
            metric: KPIFormat.percent(share),
            explanation: "\(topModel.name) accounts for \(KPIFormat.percent(share)) of month-to-date AI spend (\(KPIFormat.currencyShort(topModel.cost)) of \(KPIFormat.currencyShort(totalSpend))). Heavy reliance on a single model increases exposure to pricing changes and rate-limit events.",
            nextStep: "Review which workloads are routed to \(topModel.name) and evaluate whether lighter-weight models could handle a portion of the load without affecting output quality.",
            caveat: "Cost share is calculated from month-to-date data only. Relative share may shift as the month progresses."
        )
    }

    // MARK: - Rule 2: Model Increase

    /// Triggers when any model's month-over-month change fraction exceeds 0.15.
    /// Picks the model with the highest change.
    private func modelIncreaseInsight() -> UsageInsight? {
        guard let fastestGrowing = costStore.modelCosts.max(by: { $0.change < $1.change }),
              fastestGrowing.change > 0.15
        else { return nil }

        return UsageInsight(
            category: .modelIncrease,
            severity: .watch,
            title: "Rapid Month-over-Month Cost Growth",
            metric: KPIFormat.signedPercent(fastestGrowing.change),
            explanation: "\(fastestGrowing.name) usage has risen \(KPIFormat.signedPercent(fastestGrowing.change)) compared to last month, the fastest increase across all models. Unchecked growth in a single model can erode budget headroom quickly.",
            nextStep: "Identify the teams or pipelines driving the increase. Confirm that the additional usage is intentional and maps to planned work.",
            caveat: "Month-over-month change is a point-in-time comparison and may reflect seasonal spikes rather than a sustained trend."
        )
    }

    // MARK: - Rule 3: Delivery Trend

    /// Triggers when the heavy-users cohort improves ticket-to-merge time
    /// by more than 10 % from first to latest month.
    private func deliveryTrendInsight() -> UsageInsight? {
        let heavySamples = ticketToMergeStore.samples
            .filter { $0.cohort == .heavyUsers }
            .sorted { $0.month < $1.month }

        guard let first = heavySamples.first,
              let latest = heavySamples.last,
              first.avgDays > 0,
              first.month != latest.month        // need at least two distinct months
        else { return nil }

        let improvement = (first.avgDays - latest.avgDays) / first.avgDays
        guard improvement > 0.10 else { return nil }

        let firstFormatted  = String(format: "%.1f", first.avgDays)
        let latestFormatted = String(format: "%.1f", latest.avgDays)

        return UsageInsight(
            category: .deliveryTrend,
            severity: .informational,
            title: "Shorter Cycle Times in High-Usage Cohort",
            metric: KPIFormat.percent(improvement),
            explanation: "The heavy-AI-usage cohort's average ticket-to-merge time has fallen \(KPIFormat.percent(improvement)) over the tracked period, from \(firstFormatted) days to \(latestFormatted) days. This pattern is consistent with process improvements observed alongside increased tooling adoption.",
            nextStep: "Investigate whether workflow changes, automation, or team capacity — rather than AI tooling alone — correlate with the shorter cycle times, and document the contributing factors.",
            caveat: "Correlation between AI tool usage and cycle-time improvement does not establish causation. Other variables such as ticket scope, team experience, and sprint structure may be significant contributors."
        )
    }

    // MARK: - Rule 4: Workflow Pattern

    /// Triggers when at least one contributor has above-median tokens AND
    /// below-median mergedPRs.  Requires at least 4 outcomes to evaluate.
    private func workflowPatternInsight() -> UsageInsight? {
        let outcomes = outcomeStore.developerOutcomes
        guard outcomes.count >= 4 else { return nil }

        let medianTokens   = median(outcomes.map(\.tokens))
        let medianPRs      = median(outcomes.map { Double($0.mergedPRs) })

        let matchingCount = outcomes.filter { outcome in
            outcome.tokens > medianTokens && Double(outcome.mergedPRs) < medianPRs
        }.count

        guard matchingCount > 0 else { return nil }

        let totalCount = outcomes.count
        let share = Double(matchingCount) / Double(totalCount)

        return UsageInsight(
            category: .workflowPattern,
            severity: .review,
            title: "High Token Use Without Proportional Output",
            metric: "\(matchingCount) of \(totalCount) contributors",
            explanation: "\(matchingCount) contributor\(matchingCount == 1 ? "" : "s") (\(KPIFormat.percent(share)) of the team) consumed above-median tokens this month while merging below-median pull requests. This pattern may indicate inefficient prompting strategies, work blocked on review, or tasks that do not produce mergeable artefacts.",
            nextStep: "Review the nature of work undertaken by contributors who fit this pattern. Consider short pairing sessions or prompting-strategy workshops if inefficiency is confirmed.",
            caveat: "Merged PR count is a coarse productivity proxy. Contributors working on long-running tasks, architecture, or code review may legitimately show high token use with fewer merges in a single month."
        )
    }

    // MARK: - Rule 5: Data Quality

    private func dataQualityInsight() -> UsageInsight {
        UsageInsight(
            category: .dataQuality,
            severity: .informational,
            title: "Insufficient Data for Analysis",
            metric: "N/A",
            explanation: "One or more data sources returned no records. Insights require cost, outcome, and cycle-time data to be present. Analysis has been skipped to avoid misleading results.",
            nextStep: "Verify that all three data stores are populated and that the dashboard is connected to the correct data sources.",
            caveat: "This message disappears automatically once all three stores contain at least one record."
        )
    }

    // MARK: - Helpers

    /// Returns the lower-median value of a sorted Double array (index count/2).
    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
