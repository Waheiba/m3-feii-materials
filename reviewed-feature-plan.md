# Reviewed Feature Plan: AI Usage Insights

## Feature summary

Add one `AI Usage Insights` row to the Tokens Dashboard summary screen. Selecting it opens one `UsageInsightsView` with up to two compact, team-level review-prompt cards: AI activity and model mix. The screen uses deterministic local rules over fixed mock data and presents observed changes without claims about performance, quality, motive, or causality.

## Audience

Team leads, engineering managers, and project leads reviewing aggregate AI-usage patterns as input to planning and retrospective conversations.

## Goals

- Preserve the existing summary-to-detail navigation pattern with one new destination.
- Help users notice qualifying changes in aggregate team token activity and model mix.
- Keep comparisons period-aligned, neutral, privacy-conscious, and independently testable.
- Clearly distinguish unavailable comparisons from changes that did not meet configured review thresholds.
- Keep all v1 inputs and card models aggregate and display-ready.

## Non-goals

- Individual developer names, records, rankings, surveillance, performance judgments, or cohort labels in insight cards.
- Delivery or ticket-to-merge insights in version 1.
- Claims that AI usage caused delivery improvements or other outcomes.
- Recommendations to use more AI, model-quality judgments, or premium, standard, or cheap model classifications.
- Runtime LLM calls, networking, persistence, authentication, or backend services.
- A tab bar, navigation redesign, alerts, forecasting, benchmarking, anomaly detection, or automated interventions.
- Per-insight detail screens, drill-downs, or card-specific destinations.
- Pricing advice or cost display in insight cards.

## User flow

1. A user opens `SummaryView`.
2. The narrative list includes one new `AI Usage Insights` row with brief, neutral team-level copy.
3. Selecting the row navigates through `DestinationGraph` to `UsageInsightsView`.
4. The screen displays qualifying cards in stable order: AI activity, then model mix.
5. If a category cannot be compared, the screen presents an informational insufficient-data state or, when another card is available, a brief neutral coverage note.
6. If all required comparisons are valid but neither rule qualifies, the screen says: “No changes met the current review thresholds for this period.”

Cards are informational only and do not navigate further.

## UI plan

The summary row uses the existing summary-row treatment and navigation affordance. Its copy should be concise and neutral, for example: “Review aggregate team AI usage patterns.”

`UsageInsightsView` contains:

- Navigation title: `AI Usage Insights`.
- Helper text that frames content as team-level review prompts.
- Up to two compact cards in a stable category order.
- An informational insufficient-data state when no category has a valid comparison.
- The threshold-specific no-qualifying-changes state when comparisons are valid but no rule qualifies.
- A neutral coverage note if a displayed card is accompanied by unavailable comparison categories.

Each card contains a neutral title, concise evidence, reporting-period context, and a cautious review prompt. Direction icons, if used, are supplementary; text must convey the same meaning. Do not use warning colors, grades, scores, rankings, urgency language, or good/bad trend treatment.

## Proposed Swift surface

- `UsageInsight`: display model with a stable category-based identity, title, evidence, review prompt, reporting-period label, and optional display-only trend direction. It contains no individual, ticket, prompt, cohort, or cost data.
- `UsageInsightCategory`: closed set with `activity` and `modelMix` values.
- `UsageInsightsState`: `insights`, `noQualifyingChanges`, and `insufficientData`, with enough availability information to present a neutral partial-coverage note.
- `UsageInsightsViewModel`: receives only local aggregate period inputs and exposes `UsageInsightsState` for rendering.
- `UsageInsightBuilder`: pure deterministic rule layer that receives aggregate period data only; it must not accept developer records, identity fields, ticket data, or cohort data.
- `UsageInsightBuilder.Configuration`: local configuration surface for thresholds, minimum volume, and stable selection behavior.
- `UsageInsightsView`: renders cards and informational states.
- `SummaryViewModel`: adds one neutral `AI Usage Insights` row.
- `DestinationGraph`: adds one `usageInsights` destination.

## Proposed files

### Add

- `Models/UsageInsight.swift`
- `ViewModels/UsageInsightsViewModel.swift`
- `Views/UsageInsightsView.swift`
- `UsageInsightBuilderTests.swift` in the app test target; add a small test target only if one does not exist.

### Modify

- `Views/SummaryView.swift`
- `ViewModels/SummaryViewModel.swift`
- `Models/CostbyModel.swift`, or a new aggregate period-data model alongside it, to provide explicit current and preceding completed-period token aggregates.
- Project configuration only when required for file discovery or the test target.

Do not use `DeveloperOutcomeStore` or `TicketToMergeStore` in the version 1 insight flow.

## Data flow

```text
Local fixed period-token aggregates
        ↓
UsageInsightsViewModel
        ↓
UsageInsightBuilder
        ↓
[UsageInsight] / UsageInsightsState
        ↓
UsageInsightsView
```

The insight input boundary is period-based rather than a current model record augmented with a prior value. Each input period must include explicit start and end timestamps, reporting timezone or calendar convention, completion status, aggregate total tokens, and aggregate token totals by stable model identifier.

The builder receives only two equal-length, completed periods: the reporting period and its immediately preceding period. It does not receive individual developer records, cohort information, delivery data, ticket records, prompts, or card-visible cost data. Input data must comply with the approved privacy policy before it reaches the feature.

## Final version 1 insight rules

Use the reporting period and immediately preceding equal-length completed period. Evaluate thresholds using unrounded values and round only for display. Suppress a category when required values are missing, negative, non-finite, incomplete, or cannot form a valid comparison.

The following values are provisional configuration inherited from the reviewed draft and require product approval:

| Rule configuration | Provisional v1 value |
| --- | --- |
| Minimum comparison volume | 1,000,000 aggregate tokens in both periods |
| AI activity threshold | Absolute relative change of at least 15% |
| Model-mix threshold | Absolute share shift of at least 10 percentage points |
| Model-shift tie-breaker | Alphabetical stable model identifier after equal absolute shifts |
| Maximum card count | Two |

### AI activity

Compare aggregate total team tokens across the two valid periods. Show a card only when both periods meet the approved minimum volume and the absolute relative change meets the approved threshold.

Example wording: “Team token activity increased 18% compared with the prior period. Review this alongside the team’s current work.”

### Model mix

Compare each model’s share of aggregate team tokens across the two valid periods. Models absent from one otherwise-valid period may be treated as zero for that period. Require positive aggregate total tokens in both periods. Show only the model with the largest absolute share shift when it meets the approved threshold; use the configured tie-breaker for equal shifts.

Example wording: “Model A’s share of team token activity increased by 12 percentage points this period. Review whether this reflects the team’s current work.”

The card must not describe a model as premium, standard, cheap, better, worse, preferred, or recommended.

### State rules

- Show `insufficientData` when no category has a valid comparison.
- Show qualifying cards when one or both categories qualify.
- When a card is shown but another category cannot be compared, show a neutral coverage note.
- Show “No changes met the current review thresholds for this period.” only when all required comparisons are valid and neither category qualifies.

## Deferred from version 1

- Delivery-context cards, until a valid team-level delivery source with period alignment and population counts is available.
- Any use of `TicketToMergeStore`, `DeveloperOutcomeStore`, individual records, or AI-usage cohorts in insight generation.
- Per-insight detail screens, drill-downs, and the optional “Explore dashboard trends” action.
- Alerts, forecasting, benchmarking, anomaly detection, and automated interventions.
- Richer model-mix distributions or multiple model-shift cards.
- Resolution of existing summary-screen individual rankings and causal language: this is a separate safety dependency before a broader release, not part of this small feature implementation.

## Edge cases

- No period data, only one period, incomplete periods, unequal-length periods, or mismatched reporting calendar/timezone.
- Missing, negative, or non-finite token values.
- Aggregate totals below the approved minimum comparison volume.
- Zero aggregate total model usage in either period.
- A model present in only one period, provided both aggregate period totals remain valid.
- Multiple qualifying model shifts or tied largest shifts.
- Valid activity data with unavailable model-mix data, and the inverse.
- All comparisons valid but below thresholds.
- Long localized model names, long review prompts, and large accessibility text sizes.
- Input that does not meet the approved privacy policy; do not create insight cards from it.

## Accessibility requirements

- Support Dynamic Type without clipping cards, helper text, or informational states.
- Maintain adequate contrast for text and card surfaces.
- Do not rely on color, icons, or layout position alone to communicate a trend.
- Keep the summary row and navigation control comfortably tappable.
- VoiceOver labels include category, observed comparison, reporting-period context, and review-oriented caution without exposing prohibited data.
- Mark decorative icons as decorative; otherwise provide equivalent accessible text.
- Present unavailable or insufficient data as information, not an error.
- Avoid motion in version 1; any later motion must respect Reduce Motion.

## Acceptance criteria

- The summary list contains exactly one new `AI Usage Insights` row.
- Selecting the row resolves through `DestinationGraph` to exactly one `UsageInsightsView`.
- The screen renders zero to two cards in activity then model-mix order, with no card-specific destinations.
- The version 1 insight flow uses no delivery, ticket-to-merge, developer-outcome, individual, cohort, ticket, prompt, or cost input.
- `UsageInsight` contains no developer names or IDs, ticket titles, prompt content, cohort labels, costs, or other prohibited sensitive source data.
- Insight rules are local, deterministic, pure, and make no runtime LLM calls, network requests, or persistence/backend operations.
- Inputs use two explicit, equal-length, completed reporting periods under one defined calendar/timezone convention.
- Activity cards require valid, finite, non-negative totals, the approved minimum volume in both periods, and an unrounded threshold-qualifying relative change.
- Model-mix cards require positive valid aggregate totals in both periods and an unrounded threshold-qualifying share shift.
- The screen distinguishes insufficient data, partial coverage, and no qualifying changes.
- Card copy is neutral, team-level, non-causal, and does not classify models by price or quality.
- Cards, informational states, and the summary row work with Dynamic Type and VoiceOver.
- Automated tests cover period alignment and completeness, thresholds and boundaries, missing periods, low volumes, zero totals, invalid numeric values, one-period-only models, tied and multiple shifts, partial coverage, and no-qualifying-change states.

## Open questions

- What minimum group size and other privacy floor must an aggregate period satisfy before the feature may display it? A group size of 10 was recommended but not decided.
- Which aggregate fields are permitted in cards, VoiceOver labels, and future data boundaries? In particular, are model names, reporting periods, or any cost-derived values sensitive?
- Who approves the provisional minimum-volume and insight thresholds, and what user need establishes their materiality?
- Does the product owner approve the final v1 card set of activity and model mix only?
- How should design present the neutral partial-coverage note and informational states?
- Who owns the separate safety work on existing summary-screen individual rankings and causal claims, and what release gate applies?
- After v1, is one representative model-share shift sufficient, or is a richer distribution needed?

## Final status

The reviewed plan is scoped for a small, local, deterministic v1 centered on team-level AI activity and model mix. Delivery context is explicitly deferred. Implementation planning can proceed, subject to stakeholder approval of privacy policy, thresholds, final card scope, state presentation, and the release treatment of the existing summary-screen safety dependency.
