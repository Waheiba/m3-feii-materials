/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import Foundation

/// Broad area an insight belongs to.
enum InsightCategory: String {
    case modelConcentration = "Model Concentration"
    case modelIncrease      = "Model Usage Increase"
    case deliveryTrend      = "Delivery Trend"
    case workflowPattern    = "Workflow Pattern"
    case dataQuality        = "Data Quality"
    case noSignal           = "No Signal"
}

/// Informal urgency label shown on each card.
enum InsightSeverity: String {
    case informational = "FYI"
    case review        = "Review"
    case watch         = "Watch"
}

/// A single team-level review prompt produced by UsageInsightsService.
struct UsageInsight: Identifiable {
    let id: UUID
    let category: InsightCategory
    let severity: InsightSeverity
    let title: String
    /// Key number or short phrase that anchors the insight.
    let metric: String
    let explanation: String
    let nextStep: String
    let caveat: String

    init(
        category: InsightCategory,
        severity: InsightSeverity,
        title: String,
        metric: String,
        explanation: String,
        nextStep: String,
        caveat: String
    ) {
        self.id          = UUID()
        self.category    = category
        self.severity    = severity
        self.title       = title
        self.metric      = metric
        self.explanation = explanation
        self.nextStep    = nextStep
        self.caveat      = caveat
    }
}
