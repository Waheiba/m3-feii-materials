# Implementation Audit: AI Usage Insights

Audits commit `6788a99` ("plan implemented") against the Goals and Non-goals in
`reviewed-feature-plan.md` (cross-checked against `execution-plan.md` and the
plan's own Acceptance Criteria / Edge Cases, since those are where a Goal is
actually falsifiable). This is an audit only — no fixes were applied.

Files reviewed: `Models/AIUsagePeriod.swift`, `Models/UsageInsight.swift`,
`Models/UsageInsightBuilder.swift`, `ViewModels/UsageInsightsViewModel.swift`,
`Views/UsageInsightsView.swift`, and the diffs to `ViewModels/SummaryViewModel.swift`
/ `Views/SummaryView.swift`.

## Summary

The core rule engine (`UsageInsightBuilder`) is a faithful, careful implementation
of the activity and model-mix rules, including the alphabetical tie-breaker,
unrounded-threshold/rounded-display split, and the three-way state distinction
(insufficient data / no qualifying changes / partial coverage). The Non-goals are
respected: no individual/cohort/cost/ticket data anywhere in the new files, no new
navigation surfaces beyond the one destination, no causal or quality language in
copy. The two most significant gaps are (1) **zero automated tests** were added
despite the plan treating them as an acceptance criterion and a proposed file, and
(2) the mock period store uses **calendar months**, which are not equal-length,
contradicting an explicit, repeated requirement ("two equal-length ... periods").

## Positive findings (Goals met)

1. **Navigation pattern preserved, single new destination.** `DestinationGraph`
   gained exactly one `.usageInsights` case; `SummaryView`'s switch gained exactly
   one corresponding line. No existing case, row, or copy was touched.
   (`Views/SummaryView.swift`)
2. **Summary row is additive-only.** `SummaryViewModel` appends exactly one new
   `Insight` with neutral copy ("AI Usage Insights" / "Review aggregate team AI
   usage patterns.") after the three existing rows, without reordering or
   rewriting them — matches the plan's explicit carve-out for the pre-existing
   individual-ranking/causal-language rows.
3. **Rule engine is pure and deterministic.** `UsageInsightBuilder` takes two
   `AIUsagePeriod` values and a `Configuration` and returns a `UsageInsightsState`
   with no I/O, no singletons, no `DeveloperOutcomeStore`/`TicketToMergeStore`
   references anywhere in the new files.
4. **Threshold math matches spec.** Activity uses unrounded `relativeChange`
   against a 15% threshold; model mix uses unrounded per-model share deltas
   against a 10-point threshold; both round only at display time
   (`Int((... * 100).rounded())`). The model-mix tie-breaker iterates
   `allModels.sorted()` and only replaces the best match on strict `>`, which
   correctly yields the first alphabetical model on a tie.
5. **State-distinction logic matches the plan's state-rules table** exactly:
   `insufficientData` when neither category is validly comparable (or when zero
   cards qualify and coverage was incomplete), `noQualifyingChanges` only when
   both categories were validly compared and neither crossed threshold, and a
   `Set<UsageInsightCategory>` of `unavailableCategories` that only ever contains
   categories that couldn't be *compared*, never ones that were compared but
   under threshold (verified against the doc comment and the branching logic).
6. **Privacy floor and cost exclusion enforced structurally, not just by
   convention.** `AIUsagePeriod` has no per-individual or cost fields at all —
   `contributorCount` is an aggregate headcount, and both builder rules gate on
   `contributorCount >= configuration.minimumGroupSize` for both periods.
7. **Card copy is neutral and non-causal.** Evidence strings ("Team token
   activity increased 18%...") and review prompts ("Review this alongside the
   team's current work.") avoid causal claims, quality/price judgments, and
   urgency language, matching both the example wording and the Non-goals list.
8. **No card-specific navigation.** `InsightCardView` is inert — no
   `NavigationLink`, no tap gesture, no destination. Matches "Cards are
   informational only and do not navigate further."
9. **Accessibility basics addressed in code.** The trend arrow is
   `.accessibilityHidden(true)` with the same information restated in the
   evidence text (not color/icon-only); the card exposes a single combined
   `accessibilityLabel` including category, evidence, period, and review prompt;
   informational states render as plain secondary-style text with no error/warning
   styling.
10. **Model-mix zero/absent-model edge cases handled.** Missing models default to
    a 0 share via `tokensByModel[model] ?? 0`, and both totals are checked for
    `> 0`, `isFinite`, matching "Models absent from one otherwise-valid period may
    be treated as zero" and "Require positive aggregate total tokens in both
    periods."

## Negative findings (gaps, deviations, or risks)

1. **No automated tests were added — Acceptance Criteria violation.**
   `reviewed-feature-plan.md`'s Proposed Files list calls for
   `UsageInsightBuilderTests.swift`, and its Acceptance Criteria explicitly
   requires automated coverage of "period alignment and completeness,
   thresholds and boundaries, missing periods, low volumes, zero totals, invalid
   numeric values, one-period-only models, tied and multiple shifts, partial
   coverage, and no-qualifying-change states." None of that exists in this
   commit. `execution-plan.md` waives this ("Unit tests ... explicitly out of
   scope for this execution plan — edge-case states are verified via Xcode
   Previews instead"), but that waiver is a scope decision made in the execution
   plan, not a resolved decision in the reviewed plan itself — the reviewed plan's
   acceptance criteria were never amended to drop the testing requirement. This
   is the largest gap between "what was reviewed/approved" and "what shipped."
2. **The substitute Preview coverage doesn't actually exercise the builder for
   most edge cases.** Of the four `#Preview`s in `UsageInsightsView.swift`, three
   (`One Card + Coverage Note`, `No Qualifying Changes`, `Insufficient Data`)
   construct a `UsageInsightsState` directly and hand it to the view model,
   bypassing `UsageInsightBuilder` entirely. Only the `Default` preview actually
   runs real data through the builder. So even judged by the execution plan's own
   (reduced) bar — "previews are the primary way to verify edge-case states" —
   the builder's threshold/boundary/tie-break/below-minimum-volume/below-group-size
   logic is exercised by nothing at all, neither tests nor previews.
3. **Mock periods are calendar months, which are not equal-length — contradicts
   an explicit, repeated plan requirement.** `AIUsagePeriodStore` builds
   `reportingPeriod`/`precedingPeriod` from calendar-month boundaries (e.g. April
   1–30 vs. March 1–31: 30 days vs. 31 days). The reviewed plan states this
   requirement three separate times: Data Flow ("two equal-length, completed
   periods"), Final v1 insight rules ("the immediately preceding equal-length
   completed period"), and Acceptance Criteria ("two explicit, equal-length,
   completed reporting periods"). `execution-plan.md` defends the calendar-month
   choice as "consistent with every other store in the app," which may be a
   reasonable practical call, but it was never reconciled with the reviewed
   plan's explicit wording, and no resolved-decision entry covers it. The rule
   math (ratios and shares) is not numerically broken by the day-count mismatch,
   but the letter of the acceptance criteria is unmet as written.
4. **`Configuration` doesn't carry all the values the Proposed Swift Surface says
   it should.** The plan describes `UsageInsightBuilder.Configuration` as covering
   "thresholds, minimum volume, and stable selection behavior." The shipped
   `Configuration` has `minimumComparisonVolume`, `minimumGroupSize`,
   `activityThreshold`, `modelMixThreshold` — but the alphabetical tie-breaker
   ("stable selection behavior") and the max-card-count of two are hardcoded in
   `buildModelMixInsight`/`build` rather than being configuration-surfaced. Low
   practical risk (both are correct as hardcoded), but it's a deviation from the
   documented surface and reduces future testability/tunability.
5. **Model-mix rule silently skips the minimum-comparison-volume threshold that
   the rule-configuration table implies is global.** The "Final v1 insight rules"
   table lists "Minimum comparison volume | 1,000,000 aggregate tokens in both
   periods" as one row among activity/model-mix/tie-breaker/max-card-count rows,
   reading as a shared precondition. The "Model mix" subsection's prose, however,
   only requires "positive aggregate total tokens in both periods." The
   implementation follows the narrower prose (`> 0`, not `>= 1_000_000`) for model
   mix while applying the full 1,000,000 minimum to activity. This may well be the
   intended reading (specific subsection overrides general table), but the plan
   itself is internally ambiguous here, and the implementation picked one reading
   without flagging the ambiguity — worth a product-owner confirmation rather than
   an implicit call.
6. **Minor VoiceOver defect: `.modelMix` category reads awkwardly.**
   `InsightCardView`'s `accessibilityLabel` builds its category prefix from
   `insight.category.rawValue.capitalized`. `"modelMix".capitalized` produces
   `"Modelmix"` (Swift's `capitalized` capitalizes per whitespace-delimited word,
   not camelCase boundaries), not the "Model mix" a VoiceOver user would expect.
   `.activity` is unaffected since it's already a single lowercase word. This
   contradicts the Accessibility Requirement that "VoiceOver labels include
   category ... without exposing prohibited data" in a genuinely legible way — the
   category is present but garbled for one of the two categories.
7. **Privacy floor and several edge cases are structurally present but never
   actually exercised by any live data path.** `contributorCount` is hardcoded to
   `42` in both mock periods and never varies, so the "fewer than 10 distinct
   contributors" edge case, the "unequal reporting calendar/timezone" edge case,
   and "incomplete period" (`isComplete: false`) edge case have no code path that
   ever produces them outside of a hand-constructed state. This overlaps with
   finding #2 but is worth calling out separately since it also affects whether
   the feature is "independently testable" as a *running app*, not just via
   previews.
8. **No dedicated Dynamic-Type / VoiceOver / contrast verification was performed
   as part of this implementation.** The view code follows reasonable patterns
   (system fonts, `.secondary` styling, combined accessibility elements), but the
   plan's Accessibility Requirements ("Support Dynamic Type without clipping,"
   "Maintain adequate contrast," "large accessibility text sizes" edge case) were
   not validated against a running build/simulator in this commit's evidence
   trail (no test target, no CI accessibility check, no changelog of manual QA).
   This is a verification gap, not a confirmed defect.

## Suggested action items

| # | Priority | Action | Rationale |
|---|----------|--------|-----------|
| 1 | High | Add `UsageInsightBuilderTests.swift` covering the Acceptance-Criteria list (thresholds/boundaries, missing/incomplete periods, low volume, zero totals, invalid numeric values, one-period-only models, tied/multiple shifts, partial coverage, no-qualifying-change) | Closes the largest gap between the reviewed plan's acceptance criteria and what shipped; the execution plan's waiver was never reflected back into the reviewed plan |
| 2 | High | Get explicit product-owner sign-off (or a written resolved-decision) on the calendar-month vs. equal-length-period conflict, then either switch the mock store to fixed equal-length windows or formally amend the plan | Currently violates plan text in three places; needs a decision, not a silent implementation choice |
| 3 | Medium | Add builder-driven (not state-constructed) previews or tests for: below-minimum-volume, below-minimum-group-size, tied model shifts, and one-period-only models | Currently nothing — preview or test — actually drives these paths through `UsageInsightBuilder` |
| 4 | Medium | Resolve the model-mix minimum-volume ambiguity explicitly (confirm whether model-mix should also require the 1,000,000-token floor, or document why "positive only" is correct) and encode the resolution in the plan's Resolved Decisions | Table vs. prose conflict in the plan itself; implementation silently picked one reading |
| 5 | Low | Fix the VoiceOver label for `.modelMix` (e.g. a `displayName`/`accessibilityName` on `UsageInsightCategory` instead of `rawValue.capitalized`) | `"Modelmix"` is not legible; contradicts a11y requirement's intent even though it's not literally "missing" |
| 6 | Low | Move the tie-breaker rule and max-card-count into `UsageInsightBuilder.Configuration` (or document why they were intentionally hardcoded) | Aligns implementation with the documented Proposed Swift Surface; improves testability of edge cases like tie-breaking |
| 7 | Low | Perform and record a manual Dynamic Type / VoiceOver / contrast pass on `UsageInsightsView` (or add a lightweight snapshot/accessibility test) | No evidence in this commit that the stated accessibility requirements were verified, only that the code follows reasonable patterns |
