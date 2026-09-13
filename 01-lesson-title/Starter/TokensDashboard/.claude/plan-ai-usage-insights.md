# Implementation approach — AI Usage Insights

plan.md is execution-ready (stale "don't implement in Module 3" line removed, all 5 open questions resolved). No project setup changes are required first — no new dependencies, no target/build settings changes. This will be plain Swift/SwiftUI files added to existing groups, following the exact conventions already used by CostbyModel/TokensOutcomes/TicketToMerge.

## Files to add

**Models/UsageInsight.swift**
- `enum InsightCategory` — cases for the four rule areas: `.modelConcentration`, `.modelUsageIncrease`, `.deliveryTrend`, `.dataQuality`. Each case exposes a `label: String` for the category chip.
- `enum InsightSeverity: String` — `.informational`, `.review`, `.watch`, each with a `label` and an accessibility-friendly `spokenLabel` (severity must never be color-only per Accessibility requirements).
- `struct UsageInsight: Identifiable` — `id` (stable UUID or slug — plan flags "duplicate insight IDs" as an edge case, so id is derived from category+title, not headline text alone), `category`, `severity`, `title`, `metric: String` (pre-formatted via `KPIFormat`, matching how `SummaryViewModel` already does it), `explanation`, `suggestedNextStep`, `caveat`.

**ViewModels/UsageInsightsService.swift**
- `struct UsageInsightsService` — takes the same three stores by constructor injection with default-arg initializers, mirroring `SummaryViewModel`'s `init(costStore: ModelCostStore = ModelCostStore(), ...)` pattern exactly (no DI container, no protocol abstraction — matches existing style).
- One private method per rule, each returning `UsageInsight?`:
  - `modelConcentrationInsight(from costStore:)` — top model share > 40% of `monthToDateSpend`, guards `monthToDateSpend > 0` and non-empty `modelCosts` (edge cases: empty list, zero spend).
  - `modelUsageIncreaseInsight(from costStore:)` — any `ModelCost.change > 0.15`; guards empty list.
  - `deliveryTrendInsight(from ticketStore:)` — reuses the same trend logic already in `SummaryViewModel` (heavy-user series first/last comparison), guards empty/single-sample series (edge cases: empty samples, only one cohort).
  - `dataQualityInsight(...)` — fires when any required input is empty/stale/undersized; this is the fallback the other three insights degrade to rather than a fourth independent rule. Includes the developer-outcome minimum-sample-size check (< 5 → guardrail), matching the exact `median` helper style already in `TokensOutcomesViewModel`.
- `func generateInsights() -> [UsageInsight]` — assembles the list from the above, skipping `nil`s, always appending the screen-level caution as static copy (not a data-derived insight) in the view layer instead — per plan's UI plan, caution note is a fixed screen element, not a card.
- Copy for every insight explanation must read as correlation, not causation, and never reference individual names — reusing `outcomeStore.developerOutcomes` only in aggregate (median, counts), never surfacing `.name`.

**ViewModels/UsageInsightsViewModel.swift**
- Thin wrapper matching `SummaryViewModel`'s style: `let insights: [UsageInsight]`, `let dateLine: String` (via `DashboardStartDate.today`, same as every other view model), computed `isDataQualityOnly: Bool` for empty-state handling.
- `init(service: UsageInsightsService = UsageInsightsService())`.

**Views/UsageInsightsView.swift**
- Follows the exact `ScrollView` → `VStack(alignment: .leading, spacing: 24)` → `.padding(24)` → `.background(Color(.systemBackground))` shell used by `TokensOutcomesView`/`TicketToMergeView` (no shared Card component exists in this project, so no new abstraction is introduced — build inline, matching precedent).
- Header block: title + subtitle, same two-`Text` pattern as other detail screens.
- Fixed caution `Text` block right under the header (not per-card — screen-level per plan).
- `ForEach(viewModel.insights)` rendering each as an inline `VStack` (category label, severity label, title, metric, explanation, suggested next step, caveat) with `.accessibilityElement(children: .combine)` and a single composed `.accessibilityLabel` string that includes category + severity + metric text (Accessibility requirement: severity/category must be in spoken text). Dynamic Type: use semantic fonts (`.subheadline`, `.footnote`) exactly like other screens — no fixed-size text anywhere in the project, so nothing extra needed here.
- If `viewModel.isDataQualityOnly`, show only the data-quality state instead of the normal list.

## Files to update

**Views/SummaryView.swift**
- Add `.usageInsights` case to `DestinationGraph`.
- Add `case .usageInsights: UsageInsightsView()` to the `navigationDestination` switch.

**ViewModels/SummaryViewModel.swift**
- Append one more `Insight` to `built`, using the stable-phrase copy from plan.md ("Team-level review signals available for May 2026. Review model concentration, token investment, and delivery trends before changing team guidance."), `destination: .usageInsights`. This is static copy per plan's Decisions section — it does not run `UsageInsightsService` just to render the summary row.

## Verification steps

1. `XcodeRefreshCodeIssuesInFile` on each new file as it's written, to catch type errors fast.
2. `BuildProject` once all files are in place.
3. Manually construct edge-case store data in a `RunCodeSnippet` (empty arrays, zero spend, 4 vs 5 developer outcomes, single-cohort ticket samples) to confirm `UsageInsightsService.generateInsights()` degrades to the data-quality state correctly rather than crashing or producing a duplicate/garbage insight.
4. Use `RenderPreview` on `UsageInsightsView.swift`'s `#Preview` (added following the same `#Preview("...")` convention as the other views) to visually confirm card layout, then again with a forced empty-store preview for the data-quality state.
5. Spot-check VoiceOver text by reading through the composed `accessibilityLabel` strings for each card type against the Accessibility requirements list in plan.md.

## What I will not touch

No changes to existing store models, no shared Card component extraction (would be premature abstraction — every existing detail screen already duplicates this layout), no persistence/networking, no per-insight detail screens, no chart-screen links.
