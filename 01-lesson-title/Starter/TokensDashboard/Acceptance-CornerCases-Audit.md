# Audit: Implementation vs. `reviewed-feature-plan.md`

Scope: commit `6788a99` ("plan implemented") audited against the plan's **Edge cases** and
**Acceptance criteria** sections. No code was changed as part of this audit. Verified by reading
`Models/AIUsagePeriod.swift`, `Models/UsageInsight.swift`, `Models/UsageInsightBuilder.swift`,
`ViewModels/UsageInsightsViewModel.swift`, `Views/UsageInsightsView.swift`,
`ViewModels/SummaryViewModel.swift`, `Views/SummaryView.swift`, `execution-plan.md`, the Xcode
project file, and a clean `xcodebuild` run.

## Summary

The core rule layer, state machine, and UI are a close and mostly faithful implementation of the
plan. The biggest gap is that **zero automated tests exist** — the plan explicitly required
`UsageInsightBuilderTests.swift`, and `execution-plan.md` unilaterally descoped that requirement
without flagging it back against the reviewed plan's acceptance criteria. There is also one
concrete correctness bug (mock periods are unequal length, and nothing checks for that) and one
accessibility bug (VoiceOver label mangles "modelMix" into "Modelmix").

---

## Negative findings

### 1. No automated tests exist — acceptance criteria explicitly unmet (High)

- The plan's **Proposed files** section calls for `UsageInsightBuilderTests.swift` in the app test
  target ("add a small test target only if one does not exist").
- The plan's **Acceptance criteria** requires: "Automated tests cover period alignment and
  completeness, thresholds and boundaries, missing periods, low volumes, zero totals, invalid
  numeric values, one-period-only models, tied and multiple shifts, partial coverage, and
  no-qualifying-change states."
- The repo has no test target at all (`xcodebuild -list` shows a single scheme, `TokensDashboard`,
  with no test target), and no `*Tests.swift` file exists anywhere in the project.
- `execution-plan.md` states up front that unit tests are "explicitly out of scope for this
  execution plan — edge-case states are verified via Xcode Previews instead." This is a
  self-acknowledged deviation from the reviewed plan, but it was never reconciled against the
  reviewed plan's acceptance criteria, which still requires automated tests.
- Previews exist for 4 states (default/two-card, one-card-plus-coverage-note,
  no-qualifying-changes, insufficient-data) but previews are not automated tests — they require a
  human to look at each one and don't run in CI or gate merges.
- **Action item:** Add a test target and `UsageInsightBuilderTests.swift` covering at minimum: the
  full edge-case list in the plan (equal/unequal length, incomplete periods, missing/negative/NaN
  values, below-minimum volume, below-minimum group size, zero model totals, one-period-only
  models, tied/multiple shifts, all four `UsageInsightsState` outcomes).

### 2. Mock data violates the "equal-length periods" input contract, and nothing checks for it (High)

- Plan (Data flow): "The builder receives only two equal-length, completed periods."
- Plan (Acceptance criteria): "Inputs use two explicit, equal-length, completed reporting periods
  under one defined calendar/timezone convention."
- Plan (Edge cases): "...unequal-length periods... " must be handled (suppressed).
- `AIUsagePeriodStore` (in `Models/AIUsagePeriod.swift`) builds the reporting period and preceding
  period from **calendar months**: with `DashboardStartDate.today` = 2026-05-01, the reporting
  period is April 2026 (30 days) and the preceding period is March 2026 (31 days). Verified by
  computing both ranges: reporting = 30 days, preceding = 31 days.
- `UsageInsightBuilder` never compares period lengths (`end - start`) between the two periods in
  either `buildActivityInsight` or `buildModelMixInsight`. There is no code path that would ever
  suppress a category for this reason, so the shipped mock data silently ships in a state the plan
  says should not be comparable as-is.
- **Action item:** Either (a) add an explicit equal-length check to the builder that suppresses a
  category when period lengths differ, or (b) change the mock data source to produce genuinely
  equal-length periods (e.g., fixed 30-day windows) — and add a test that a deliberately
  unequal-length pair suppresses both categories.

### 3. `AIUsagePeriod` is missing the "reporting timezone or calendar convention" field (Medium)

- Plan (Data flow): "Each input period must include explicit start and end timestamps, reporting
  timezone or calendar convention, completion status, aggregate total tokens, and aggregate token
  totals by stable model identifier."
- `AIUsagePeriod` has `start`, `end`, `isComplete`, `contributorCount`, `totalTokens`,
  `tokensByModel` — there is no explicit timezone/calendar field. The implementation implicitly
  relies on `Calendar.current` at the call site (in `periodLabel(...)` and in
  `AIUsagePeriodStore.init`), which is not the same as the period carrying its own explicit
  convention per the plan's data contract.
- Related edge case ("mismatched reporting calendar/timezone") is therefore structurally
  impossible to detect or exercise, because the type has no field to disagree on.
- **Action item:** Decide whether this is a deliberate simplification for a local/mock-only v1
  (reasonable, given no real backend) or should be added to the struct now so the contract is
  explicit and testable later. If deliberately simplified, note the decision in the plan's
  Resolved decisions so it isn't re-flagged as a gap in a future review.

### 4. VoiceOver label uses the raw enum case, not the display title — produces "Modelmix" (Medium)

- Plan (Accessibility requirements): "VoiceOver labels include category, observed comparison,
  reporting-period context, and review-oriented caution without exposing prohibited data."
- `InsightCardView.body` in `Views/UsageInsightsView.swift` builds the accessibility label from
  `insight.category.rawValue.capitalized`, not from `insight.title` (which is the nicely formatted
  "AI Activity" / "Model Mix" shown visually in the same card).
- `String.capitalized` capitalizes per-word by whitespace, not by camelCase boundary, so
  `"modelMix".capitalized` evaluates to `"Modelmix"` (verified with a standalone Swift script), not
  "Model Mix". VoiceOver users hear "Modelmix: <evidence>. <period>. <prompt>" for that card while
  sighted users see "Model Mix" — an inconsistent and slightly garbled category name is exposed
  only to VoiceOver users.
- **Action item:** Build the accessibility label from `insight.title` (or another human-readable
  string) instead of `category.rawValue.capitalized`.

### 5. `insufficientData` vs. `noQualifyingChanges` resolves an ambiguous plan case via an undocumented interpretation (Low/Medium — confirm intent)

- Plan (State rules) literally says:
  - "Show `insufficientData` when no category has a valid comparison."
  - "Show `noQualifyingChanges`... only when all required comparisons are valid and neither
    category qualifies."
- Neither bullet explicitly covers the case where **one** category is validly comparable but
  doesn't cross its threshold, and the **other** category cannot be compared at all (i.e., mixed
  validity, zero qualifying cards).
- `UsageInsightBuilder.build(...)` resolves this specific case as `insufficientData` (see the
  comment block above `UsageInsightsState` and the `else` branch at the end of `build`), reasoning
  that "there is nothing to display and coverage was incomplete."
- This is a defensible reading, and the plan's edge-case list does include "Valid activity data
  with unavailable model-mix data, and the inverse" as something to handle — but the plan never
  states the resulting *state* for the sub-case where the valid category also fails to qualify.
  The implementation's comment effectively makes a product decision inline in code rather than in
  the plan.
- **Action item:** Confirm with whoever owns `reviewed-feature-plan.md` that "mixed
  validity + zero qualifying cards → insufficientData" (rather than, say, still showing a coverage
  note plus the no-qualifying-changes copy) is the intended behavior, and add it to the plan's
  State rules explicitly so it isn't ambiguous in the next review.

### 6. `UsageInsightBuilder.Configuration` doesn't expose "stable selection behavior" or max card count as data (Low)

- Plan (Proposed Swift surface): "`UsageInsightBuilder.Configuration`: local configuration surface
  for thresholds, minimum volume, **and stable selection behavior**."
- Plan (rule-configuration table) also lists "Maximum card count: Two" as a named configuration
  value.
- The shipped `Configuration` struct only has `minimumComparisonVolume`, `minimumGroupSize`,
  `activityThreshold`, `modelMixThreshold`. The alphabetical tie-breaker is hardcoded in
  `buildModelMixInsight` (not a `Configuration` property), and "maximum card count" isn't
  represented as data anywhere — it's an emergent property of there being exactly two categories.
- Functionally harmless today (there are only two categories, so "max two cards" is automatically
  true, and the tie-breaker has only one sensible value), but it's a minor deviation from the
  proposed surface and would need to be revisited if a third category is ever added.
- **Action item:** Low priority. Consider folding the tie-breaker rule and max-card-count into
  `Configuration` if/when a third insight category is planned; not worth doing for v1 alone.

---

## Positive findings (plan requirements verified as correctly implemented)

- **Summary row**: Exactly one new row added to `SummaryViewModel`, appended without touching the
  three existing rows (headline/copy/order unchanged), matching the plan's non-goal "must not
  modify or remove the existing summary or detail screen rows."
- **Navigation**: `DestinationGraph` gained exactly one new case (`usageInsights`), wired through
  `navigationDestination(for:)` to exactly one `UsageInsightsView()`; no per-card destinations
  exist in `UsageInsightsView`.
- **No forbidden data sources**: `AIUsagePeriod`, `UsageInsight`, `UsageInsightBuilder`,
  `UsageInsightsViewModel` contain no references to `DeveloperOutcomeStore`, `TicketToMergeStore`,
  cost/price fields, individual identifiers, ticket data, prompts, or cohort labels (verified by
  grep across the new insight-flow files).
- **Privacy floor**: Both `buildActivityInsight` and `buildModelMixInsight` require
  `contributorCount >= configuration.minimumGroupSize` (10) in both periods before treating a
  comparison as valid.
- **Minimum volume**: Activity rule requires both periods' `totalTokens >= 1,000,000`; correctly
  uses the unrounded relative change for the threshold check and only rounds for display
  (`Int((abs(relativeChange) * 100).rounded())`).
- **Model-mix correctness**: Requires positive totals in both periods; treats a model absent from
  one period as zero share for that period (`tokensByModel[model] ?? 0`); selects only the single
  largest absolute share shift; tie-break iterates `allModels.sorted()` with a strict `>`
  comparison so the alphabetically-first model wins ties — matches the plan's tie-breaker exactly.
- **Exact required copy**: The no-qualifying-changes string is reproduced verbatim: "No changes met
  the current review thresholds for this period."
- **Card copy neutrality**: Evidence/review-prompt strings closely track the plan's example
  wording, use no premium/cheap/better/worse/recommended language, and contain no warning colors —
  icons are supplementary (`arrow.up`/`arrow.down`) and always paired with "increased"/"decreased"
  text, and decorative icons are marked `.accessibilityHidden(true)`.
- **No runtime calls**: The entire insight flow (`AIUsagePeriodStore` → `UsageInsightsViewModel` →
  `UsageInsightBuilder` → `UsageInsightsView`) is pure/local — no networking, persistence, or LLM
  calls.
- **Builds clean**: `xcodebuild -scheme TokensDashboard build` succeeds with `BUILD SUCCEEDED` and
  no errors.
- **Dynamic Type / no truncation**: No `.lineLimit` or `.fixedSize` modifiers constrain card text,
  helper text, or informational states, so long model names/prompts and large accessibility text
  sizes should reflow rather than clip (not verified empirically, since there is no UI test
  coverage — see Finding 1).

---

## Suggested priority order for follow-up

1. Add the missing test target + `UsageInsightBuilderTests.swift` (Finding 1) — this is the
   plan's own explicit deliverable and acceptance criterion, and unblocks verifying Findings 2 and
   5 with real regression coverage instead of manual preview inspection.
2. Fix or explicitly accept the unequal-length mock periods (Finding 2).
3. Fix the VoiceOver label to use `insight.title` (Finding 4) — small, isolated fix.
4. Get an explicit ruling from the plan owner on the mixed-validity edge case (Finding 5) and fold
   it back into `reviewed-feature-plan.md`.
5. Decide whether the missing timezone/calendar field (Finding 3) and the
   `Configuration`/proposed-surface gaps (Finding 6) need action now or can be deferred with a note
   in the plan's Resolved decisions.
