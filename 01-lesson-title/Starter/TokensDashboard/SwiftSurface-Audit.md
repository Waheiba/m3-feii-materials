# Audit: Implementation vs. Reviewed Feature Plan

Scope: commit `6788a99` ("plan implemented") audited against `reviewed-feature-plan.md`'s **Proposed Swift surface** and **Proposed files** sections (with `execution-plan.md` used as supporting context where it explains a deviation). No code was changed as part of this audit; the project was built (`xcodebuild`) only to confirm compilability.

Overall: the core surface (types, navigation wiring, summary row, card copy, privacy-sensitive field exclusions) is implemented faithfully and the project builds. The most significant gaps are (1) a complete absence of automated tests despite the reviewed plan listing them as a required file and multiple acceptance criteria, (2) the `#Preview` fixtures that were meant to substitute for tests mostly bypass the rule engine rather than exercising it, and (3) the mock period data does not actually satisfy the plan's "two equal-length periods" and "explicit calendar/timezone convention" data-flow requirements.

---

## 1. Proposed Swift surface — item by item

| Surface item | Status | Notes |
| --- | --- | --- |
| `UsageInsight` | ✅ Positive | `category`, `title`, `evidence`, `reviewPrompt`, `reportingPeriodLabel`, optional `trendDirection`; `id` derived from `category` (stable category-based identity). No individual/ticket/prompt/cohort/cost fields. |
| `UsageInsightCategory` | ✅ Positive | Exactly `.activity` / `.modelMix`, closed `enum`. |
| `UsageInsightsState` | ✅ Positive | `.insights(cards:unavailableCategories:)`, `.noQualifyingChanges`, `.insufficientData`. `unavailableCategories` carries exactly the availability info needed for the partial-coverage note. Doc comments in `UsageInsight.swift` explicitly (and correctly) distinguish "invalid comparison" from "valid but below threshold." |
| `UsageInsightsViewModel` | ✅ Positive | Receives an `AIUsagePeriodStore` + `UsageInsightBuilder` (both local, no I/O) and exposes `UsageInsightsState`. Secondary `init(state:)` exists purely to support previews/tests. |
| `UsageInsightBuilder` | ✅ Positive | Pure `struct`, deterministic `build(reportingPeriod:precedingPeriod:)`, no I/O, no references to `DeveloperOutcomeStore`/`TicketToMergeStore`/identity fields. |
| `UsageInsightBuilder.Configuration` | ⚠️ Partial | Covers thresholds and minimum volume (`minimumComparisonVolume`, `minimumGroupSize`, `activityThreshold`, `modelMixThreshold`), but the plan also calls out "**stable selection behavior**" as part of the configuration surface. The alphabetical tie-breaker and the "max two cards" rule are hardcoded in `UsageInsightBuilder`'s private logic rather than exposed on `Configuration`. Functionally correct, but not fully matching the described surface. |
| `UsageInsightsView` | ✅ Positive | Renders cards + all three informational states with neutral styling (no warning colors/icons/urgency language). |
| `SummaryViewModel` | ✅ Positive | Appends exactly one `Insight` row; the three existing rows (cost-by-model, tokens-vs-outcomes, ticket-to-merge) are untouched, including their existing causal/individual-ranking language, matching the plan's explicit non-goal. |
| `DestinationGraph` | ✅ Positive | Adds exactly one `.usageInsights` case and one corresponding `navigationDestination` switch case; existing cases untouched. |

---

## 2. Proposed files — item by item

### Add

| File | Status | Notes |
| --- | --- | --- |
| `Models/UsageInsight.swift` | ✅ Added | Matches plan. |
| `ViewModels/UsageInsightsViewModel.swift` | ✅ Added | Matches plan. |
| `Views/UsageInsightsView.swift` | ✅ Added | Matches plan. |
| `UsageInsightBuilderTests.swift` (app test target) | ❌ **Missing** | No test target exists in `TokensDashboard.xcodeproj` (confirmed via `project.pbxproj` — only one `PBXNativeTarget`), and no test file was added anywhere. The reviewed plan lists this file under "Add" and explicitly says to "add a small test target only if one does not exist" — i.e., the plan anticipated and required this. `execution-plan.md` states tests are "explicitly out of scope for this execution plan," but that is a scope decision made in the *execution* companion doc, not a re-approval of the *reviewed* plan's acceptance criteria (see §4). |
| `Models/UsageInsightBuilder.swift` (not explicitly listed) | ℹ️ Neutral/extra | Not named in the reviewed plan's "Proposed files → Add" list, but the "Proposed Swift surface" section does describe `UsageInsightBuilder` as a distinct type, and `execution-plan.md` explicitly rationalizes splitting it into its own file. Reasonable, consistent with intent — just worth noting the two plan documents disagree slightly on file layout. |

### Modify

| File | Status | Notes |
| --- | --- | --- |
| `Views/SummaryView.swift` | ✅ Modified | Adds `.usageInsights` case + view mapping only. |
| `ViewModels/SummaryViewModel.swift` | ✅ Modified | Appends row #4 only. |
| `Models/CostbyModel.swift` **or** new aggregate period model | ✅ Satisfied via alternative | Plan explicitly allowed "`Models/CostbyModel.swift`, **or a new aggregate period-data model alongside it**." Implementation added an independent `Models/AIUsagePeriod.swift` instead of touching `CostbyModel.swift`, which keeps cost data fully out of the insight path — the more privacy-conservative of the two options the plan offered. |
| Project configuration | ✅ N/A | Project uses Xcode 16 file-system-synchronized groups (`PBXFileSystemSynchronizedRootGroup`), so new files needed no explicit `project.pbxproj` entries. Confirmed the project builds (`xcodebuild ... build` → `BUILD SUCCEEDED`). No test target was created, so no project configuration was needed there either — but see the missing-tests finding above. |

---

## 3. Rule-engine fidelity (beyond the surface/file checklist)

Spot-checked against the "Final version 1 insight rules" table and the acceptance criteria, since these are where subtle deviations are most consequential.

- ✅ Thresholds match exactly: 1,000,000 min volume, 10-contributor privacy floor, 15% activity threshold, 10-point model-mix threshold — all wired into `Configuration` with the plan's exact numbers.
- ✅ Activity rule correctly requires only *non-negative* finite totals (`>= 0`), while model-mix correctly requires *positive* finite totals (`> 0`) — this exactly matches the plan's differentiated wording ("non-negative" for activity vs. "positive" for model mix in the rule text and acceptance criteria) rather than treating both rules identically.
- ✅ Alphabetical tie-break for equal model-mix shifts is implemented correctly (sorted iteration + strict `>` comparison so the first alphabetical model wins ties).
- ✅ Threshold comparisons use unrounded values; rounding (`Int(...rounded())`) is applied only to display strings — matches "evaluate using unrounded values, round only for display."
- ✅ Card copy matches the plan's example wording verbatim for both activity and model-mix cards, and avoids premium/standard/cheap/better/worse/preferred/recommended language.
- ⚠️ **Ambiguity, not clearly resolved either way**: the rule-configuration table lists "Minimum comparison volume: 1,000,000 aggregate tokens **in both periods**" as one global row, but the model-mix rule's prose only requires *positive* totals, not the 1,000,000 floor. The implementation follows the model-mix prose (no 1M floor for model mix) rather than the table row. This is a defensible reading, but the plan itself is ambiguous on whether the 1M floor is meant to gate model-mix comparisons too — worth a one-line clarification from the product owner rather than leaving it to implementation discretion.
- ⚠️ **State-rule gap inherited from the plan, handled but not explicitly authorized**: the plan's "State rules" section only defines outcomes for (a) no category valid, (b) all valid, (c) one-or-both qualifying. It does not say what to show when one category is valid-but-below-threshold and the other category is invalid (zero cards, mixed validity). The implementation buckets this into `.insufficientData` and documents the reasoning clearly in code comments — a sensible call, but it's an interpretation of a gap in the reviewed plan, not something the plan explicitly sanctioned. Worth flagging back to whoever owns plan sign-off.
- ❌ **Equal-length period requirement not actually satisfied or checked**: the data-flow section requires "two equal-length, completed periods," and the Edge Cases section separately lists "unequal-length periods" as something the system must handle. `AIUsagePeriodStore` generates two **consecutive calendar months** (e.g., April = 30 days vs. March = 31 days) — these are not equal-length, and `UsageInsightBuilder` never compares period durations at all (no `end - start` equality check anywhere). So both the mock data and the builder silently violate this stated invariant instead of suppressing or flagging it.
- ❌ **No explicit calendar/timezone field on the period model**: the data-flow section requires each period to carry "explicit start and end timestamps, **reporting timezone or calendar convention**, completion status, ..." `AIUsagePeriod` has `start`, `end`, `isComplete`, `contributorCount`, `totalTokens`, `tokensByModel` — there is no timezone/calendar-convention field. This means the "mismatched reporting calendar/timezone" edge case (explicitly called out in Edge Cases) has no data to even compare against; it cannot be detected by construction.

## 4. Test / verification coverage gap

This is the largest gap in the audit and worth calling out on its own.

- The reviewed plan's acceptance criteria include: *"Automated tests cover period alignment and completeness, thresholds and boundaries, missing periods, low volumes, zero totals, invalid numeric values, one-period-only models, tied and multiple shifts, partial coverage, and no-qualifying-change states."* None of this exists — no test target, no test file.
- `execution-plan.md` substitutes `#Preview` fixtures for tests, explicitly stating: *"these previews are the primary way to verify edge-case states since unit tests are out of scope."* However, of the four required preview fixtures:
  - **"Default"** genuinely exercises the real `AIUsagePeriodStore` → `UsageInsightBuilder` pipeline and happens to produce two qualifying cards (activity +25%, model-mix Opus +15pp) — this one *does* exercise real rule logic.
  - **"One Card + Coverage Note,"** **"No Qualifying Changes,"** and **"Insufficient Data"** all construct a `UsageInsightsState` (or a hand-built `UsageInsight`) directly via `UsageInsightsViewModel(state:)`, bypassing `AIUsagePeriod`/`UsageInsightBuilder` entirely. They verify that `UsageInsightsView` renders each state correctly, but they verify nothing about *when the builder should produce that state* — in particular, the "insufficient data (below minimum volume/group size)" preview that T5 called for does not actually construct a below-threshold `AIUsagePeriod` and run it through the builder.
- Net effect: the rule engine's handling of the privacy floor, minimum volume, threshold boundaries, tie-breaks, and the mixed-validity case above has **zero automated or preview-based verification**. Only the "happy path" default scenario is exercised end-to-end.

## 5. Accessibility / copy detail

- ⚠️ Minor VoiceOver defect: `InsightCardView`'s accessibility label uses `insight.category.rawValue.capitalized`. For `.modelMix` this produces **"Modelmix"** (Swift's `.capitalized` only uppercases the first letter of a single-word string; it does not insert a space at the camelCase boundary), so VoiceOver announces "Modelmix: Model A's share of team token activity increased by 12 percentage points…" instead of "Model Mix: …". Cosmetic, but worth a one-line fix (e.g., a small `displayName` on `UsageInsightCategory` instead of deriving from `rawValue`).
- ✅ Decorative trend arrows are marked `.accessibilityHidden(true)`; the same meaning is carried in the evidence text via "increased"/"decreased" wording, per the plan's requirement that icons be supplementary.
- ✅ No color-only trend signaling (icon and text both use `.secondary`/default styling, no red/green).
- ℹ️ Long-localized-model-name and large-Dynamic-Type edge cases from the plan are not independently verified (no manual/simulated test was run as part of this audit), and the app has no localization infrastructure (`.xcstrings`/`.strings`) at all — consistent with the rest of the codebase, so not a regression, but also not a demonstrated pass.

## 6. Build verification

- `xcodebuild -project TokensDashboard.xcodeproj -scheme TokensDashboard -destination 'generic/platform=iOS Simulator' build` → **BUILD SUCCEEDED**. All five new/changed Swift files compile and are picked up automatically via the project's file-system-synchronized group (no manual `project.pbxproj` target-membership edits were needed or missing).

---

## Suggested action items

1. **Add the missing test coverage.** Create the app's first unit-test target and `UsageInsightBuilderTests.swift` (or explicitly get sign-off to formally waive the reviewed plan's acceptance criteria if tests are deliberately deferred past v1 — right now the deferral lives only in a companion execution doc, not in the reviewed plan itself). At minimum, cover: privacy floor, minimum volume, threshold boundaries (exactly at 15%/10pp), tie-breaking, mismatched-validity case, zero/negative/non-finite inputs.
2. **Rework the three non-"Default" `#Preview` fixtures to go through `AIUsagePeriod` + `UsageInsightBuilder`** rather than hand-constructing `UsageInsightsState`, so they actually exercise the rule engine's edge-case handling as T5 intended — especially the "insufficient data (below minimum volume/group size)" case.
3. **Resolve the equal-length-period gap**: either make `AIUsagePeriodStore` produce genuinely equal-length periods, or add an explicit equal-length check/suppression in `UsageInsightBuilder` (with a corresponding edge-case test) so the plan's stated invariant is actually enforced rather than silently assumed.
4. **Add a timezone/calendar-convention field to `AIUsagePeriod`** (or explicitly document why it's out of scope for v1) so the "mismatched calendar/timezone" edge case in the plan is representable at all.
5. **Get explicit sign-off on two ambiguous rule interpretations** from whoever owns the reviewed plan: (a) whether the 1,000,000-token minimum-volume floor should also gate model-mix comparisons, and (b) whether "one category valid-but-below-threshold + one category invalid" should map to `insufficientData` (current behavior) or some other treatment — the plan's state rules don't explicitly cover this combination.
6. **Fix the VoiceOver label for `.modelMix`** (currently announces "Modelmix") — small, low-risk copy fix.
7. **Consider moving the tie-breaker/max-card-count rule into `UsageInsightBuilder.Configuration`**, or note explicitly why they're intentionally hardcoded, to fully match the "Proposed Swift surface" description of `Configuration` as covering "stable selection behavior."
