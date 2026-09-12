# Acceptance Criteria Review: AI Usage Insights

Reviewed against the executed implementation in
`01-implementing-plan/Final/TokensDashboard/`. Each item from the plan's
"Acceptance criteria" section is assessed as **Satisfied**, **Partially
satisfied**, or **Not satisfied**, with the evidence used to reach that
verdict.

---

### 1. The summary list contains exactly one new `AI Usage Insights` row.

**Satisfied.** `SummaryViewModel.init` appends exactly one `Insight` with
headline `"AI Usage Insights"` and `destination: .usageInsights`
(`ViewModels/SummaryViewModel.swift:62-66`).

### 2. Selecting the row resolves through `DestinationGraph` to exactly one `UsageInsightsView`.

**Satisfied.** `DestinationGraph` gained a `.usageInsights` case
(`Views/SummaryView.swift:9-14`), and `SummaryView`'s
`.navigationDestination(for: DestinationGraph.self)` maps it to exactly one
`UsageInsightsView()` (`Views/SummaryView.swift:55-62`).

### 3. The screen renders zero to two cards in activity then model-mix order, with no card-specific destinations.

**Satisfied.** `UsageInsightBuilder.build` always evaluates and appends
activity before modelMix (`ViewModels/UsageInsightsViewModel.swift:33-50`),
and caps the result at `configuration.maximumCardCount` (2). `InsightCard`
in `Views/UsageInsightsView.swift:53-85` is a plain `VStack` of `Text`/`Image`
— no `NavigationLink`, button, or destination.

### 4. The version 1 insight flow uses no delivery, ticket-to-merge, developer-outcome, individual, cohort, ticket, prompt, or cost input.

**Satisfied.** `UsageAggregatePeriodStore` (`Models/UsageAggregatePeriod.swift`)
only exposes `totalTokens` and `modelTokenTotals`. A grep across the
insight-flow files (`UsageInsight.swift`, `UsageAggregatePeriod.swift`,
`UsageInsightsViewModel.swift`, `UsageInsightsView.swift`) turns up zero
references to `TicketToMergeStore`, `DeveloperOutcomeStore`, or
`ModelCostStore`.

### 5. `UsageInsight` contains no developer names or IDs, ticket titles, prompt content, cohort labels, costs, or other prohibited sensitive source data.

**Satisfied.** `UsageInsight` (`Models/UsageInsight.swift:31-40`) has only
`category`, `title`, `evidence`, `reviewPrompt`, `periodLabel`,
`trendDirection`. The only identifying data surfaced is the model name
(e.g. "Claude Opus 4.8"), which the resolved decisions log explicitly
permits.

### 6. Insight rules are local, deterministic, pure, and make no runtime LLM calls, network requests, or persistence/backend operations.

**Satisfied.** `UsageInsightBuilder` (`ViewModels/UsageInsightsViewModel.swift:10-177`)
is a pure struct: `build` is a deterministic function of its two arguments,
with no I/O, networking, or persistence anywhere in the type.

### 7. Inputs use two explicit, equal-length, completed reporting periods under one defined calendar/timezone convention.

**Satisfied.** `periodsFormValidComparison` requires both periods
`isComplete`, `start < end`, `preceding.end == reporting.start` (adjacency),
matching time zones, and equal day-counts
(`ViewModels/UsageInsightsViewModel.swift:63-73`). Covered by
`adjacentEqualLengthCompletePeriodsAreValid`, `gapBetweenPeriodsIsInvalid`,
`unequalLengthPeriodsAreInvalid`, `incompletePeriodIsInvalid`, and
`mismatchedTimeZoneIsInvalid` in `UsageInsightBuilderTests.swift`.

### 8. Activity cards require valid, finite, non-negative totals, the approved minimum volume in both periods, and an unrounded threshold-qualifying relative change.

**Satisfied.** `activityComparison` guards `isFinite`, `>= 0`, and
`>= minimumComparisonVolume` for both periods
(`ViewModels/UsageInsightsViewModel.swift:94-101`). `qualifyingInsight(for:
activity:)` compares the raw `activity.relativeChange` against the threshold
and only rounds via `KPIFormat.percent` for display
(`ViewModels/UsageInsightsViewModel.swift:148-161`).

### 9. Model-mix cards require positive valid aggregate totals in both periods and an unrounded threshold-qualifying share shift.

**Satisfied.** `modelMixComparison` requires `totalTokens > 0` (not just
`>= 0`) and finiteness for both periods, and the threshold check in
`qualifyingInsight(for: modelMix:)` uses the unrounded
`absoluteShiftPercentagePoints`, rounding only the display string
(`ViewModels/UsageInsightsViewModel.swift:112-176`).

### 10. The screen distinguishes insufficient data, partial coverage, and no qualifying changes.

**Satisfied, with one unresolved edge case.** `UsageInsightsView.content`
renders three visually distinct states (`Views/UsageInsightsView.swift:26-48`):
an `insights` case with an optional `CoverageNote` for partial coverage, a
`noQualifyingChanges` case, and a dedicated `insufficientData` message.

However, the plan's own state rules are ambiguous for the case where **one**
category is validly compared but doesn't cross its threshold, while the
**other** category is unavailable (e.g., activity change is only 5%, and
model-mix data is missing). The plan says the "No changes met the current
review thresholds" message should appear "only when all required
comparisons are valid" — but in `UsageInsightBuilder.build`, this exact
scenario falls into `.noQualifyingChanges` too (since `cards.isEmpty` is
true regardless of *why* modelMix didn't produce a card). The implementation
resolves this reasonably by pairing the message with a coverage note, but
this specific combination isn't called out in the plan's state rules and
isn't covered by a dedicated test — worth a product/design confirmation
that showing "no changes met thresholds" *and* a coverage note together is
the intended behavior, rather than, say, treating it as closer to
`insufficientData`.

### 11. Card copy is neutral, team-level, non-causal, and does not classify models by price or quality.

**Satisfied.** Activity copy: "Team token activity increased/decreased X%
compared with the prior period. Review this alongside the team's current
work." Model-mix copy: "[Model]'s share of team token activity
increased/decreased by X percentage points this period. Review whether this
reflects the team's current work." Both match the plan's example wording
verbatim in structure, and neither uses premium/cheap/better/worse language
(`ViewModels/UsageInsightsViewModel.swift:148-176`).

### 12. Cards, informational states, and the summary row work with Dynamic Type and VoiceOver.

**Satisfied.** All text uses semantic/system fonts (`.subheadline`,
`.title3`, `.caption`, etc.) with no fixed frame heights or `lineLimit`
truncation that would clip scaled text. `InsightCard` combines its
accessibility children into one label containing category, evidence,
review prompt, and period label
(`Views/UsageInsightsView.swift:80-83`), matching the accessibility
requirement. The trend arrow is marked `.accessibilityHidden(true)` since
the same information is already in the evidence text. `InformationalState`
and `CoverageNote` also use `.accessibilityElement(children: .combine)`.

### 13. Automated tests cover period alignment and completeness, thresholds and boundaries, missing periods, low volumes, zero totals, invalid numeric values, one-period-only models, tied and multiple shifts, partial coverage, and no-qualifying-change states.

**Partially satisfied.** `UsageInsightBuilderTests.swift` has strong,
explicit coverage for: period alignment/completeness (gap, unequal length,
incomplete, mismatched time zone), threshold boundaries (exact/just-below),
low volume, zero totals, negative/non-finite values, one-period-only models,
tied shifts, multiple shifts, below-threshold model shifts, partial coverage,
no-qualifying-changes, and the two-card cap.

The one item from the list **not represented** is "missing periods" in the
literal sense of a period being absent altogether (as opposed to present
but incomplete or misaligned). `UsageInsightBuilder.build(precedingPeriod:
reportingPeriod:)` takes two non-optional `UsageAggregatePeriod` values, so
there's no code path — and therefore no possible test — for "no period
data" or "only one period" as the plan's own Edge Cases section describes
it. `gapBetweenPeriodsIsInvalid` and `incompletePeriodIsInvalid` are the
closest analogues but test adjacency and completion status, not absence of
data. This is a gap between the plan's edge cases and the type it chose for
the input boundary — either the plan's "missing periods" language should be
understood as fully covered by "incomplete periods," or the store/view model
needs an optional-period path (and a test for it) to genuinely satisfy this
criterion as written.

---

## Summary

12 of 13 acceptance criteria are fully satisfied by the implementation.

- **#10** (distinguishing the three states) is satisfied by the UI, but rests
  on a state-transition rule the plan itself left ambiguous — flag for
  product sign-off rather than a code fix.
- **#13** (test coverage) is satisfied for every scenario the current data
  model can express, but "missing periods" specifically has no
  corresponding test because the builder's non-optional period parameters
  make that scenario unrepresentable. Decide whether the plan's language
  should be reinterpreted or the input boundary should support it.

No other gaps, prohibited data leaks, or deviations from the reviewed plan
were found in the executed feature.
