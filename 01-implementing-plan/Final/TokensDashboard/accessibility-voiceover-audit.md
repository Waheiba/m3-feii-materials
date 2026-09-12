# VoiceOver Accessibility Audit — TokensDashboard

Scope: `TokensDashboard/Views/*.swift` (ContentView, SummaryView, CostbyModelView,
TicketToMergeView, TokensOutcomesView, UsageInsightsView).

## Verdict: FAIL

One custom page-level heading is missing the Header trait, so it will not
appear in VoiceOver's Headings rotor and will not be announced as a heading.
All other interactive elements, charts, and images are correctly configured.

---

## Failing elements

### 1. Custom page title missing Header trait
**File:** `SummaryView.swift`, line 22 (`Heading` struct, used at line 41)

```swift
Text(title)
  .font(.system(.largeTitle, design: .serif, weight: .semibold))
```

`SummaryView` sets `.navigationTitle("")` (line 53) and renders its own
large-title text instead of relying on the system navigation bar title. Because
the real `navigationTitle` is empty, VoiceOver gets no automatic heading
announcement for this screen — the custom `Heading` text is the only visual
title, but it carries no heading semantics, so it won't show up in the
Headings rotor and won't be announced as "Token's Dashboard Summary, heading."

**Fix:** Add `.accessibilityAddTraits(.isHeader)` to the title `Text` in `Heading`:
```swift
Text(title)
  .font(.system(.largeTitle, design: .serif, weight: .semibold))
  .accessibilityAddTraits(.isHeader)
```

---

## Passing elements

- **`ContentView.swift`** — no interactive elements, images, or custom views. Exempt.
- **`SummaryView.swift` line 43–46** — `NavigationLink(value:) { InsightRow(...) }`: standard control, correct traits by default.
- **`SummaryView.swift` line 68–91 (`InsightRow`)** — combines children (`accessibilityElement(children: .combine)`, line 88) and overrides with an explicit human-readable label (line 89: `"\(insight.headline) \(insight.detail)"`). The decorative `Image(systemName: "chevron.right")` (line 77) is absorbed into the combine with no extra announcement. Passes Criteria 1, 2, 4.
- **`CostbyModelView.swift` line 28–51 (`donut`)** — `Chart` has an explicit `.accessibilityLabel(...)` (line 50) summarizing chart type, subject, and total. Passes Criterion 4.
- **`CostbyModelView.swift` line 63–86 (`SliceRow`)** — combines children (line 84); the decorative color-swatch `Circle()` carries no text and is silently absorbed. Text content (`slice.name`, share/change, cost) is read as one unit. Passes.
- **`TicketToMergeView.swift` line 32–58 (`lines`)** — `Chart` has an explicit `.accessibilityLabel(accessibilitySummary)` (line 57) that names the chart type, both axes/cohorts, and every point's value. Passes Criterion 4.
- **`TokensOutcomesView.swift` line 40–54** — each `PointMark` has an explicit `.accessibilityLabel(point.name)` and `.accessibilityValue(...)` (lines 52–53) describing tokens/PRs and quadrant. Passes Criteria 1, 4.
- **`UsageInsightsView.swift` line 53–85 (`InsightCard`)** — combines children (line 80) with an explicit override label (lines 81–83) covering category, evidence, review prompt, and period. The trend arrow `Image(systemName:...)` (line 63) is correctly marked `.accessibilityHidden(true)` (line 66) since its meaning is redundant with the text. Passes Criteria 1, 4.
- **`UsageInsightsView.swift` line 89–100 (`InformationalState`)** and **line 102–113 (`CoverageNote`)** — plain static text, not interactive, combined for good measure. Exempt/passes.

---

## Recommendations (do not affect verdict)

- **`TokensOutcomesView.swift` line 47–51** — the `.annotation` `Text(point.name)` renders as a separate overlay view alongside the `PointMark` that already carries `point.name` in its `.accessibilityLabel`. Verify with VoiceOver that this doesn't produce a duplicate "point.name" announcement distinct from the mark's label/value; if it does, add `.accessibilityHidden(true)` to the annotation `Text`.
- **`TokensOutcomesView.swift` line 34–39** — the two dashed `RuleMark` median-reference lines have no accessibility exposure. This is likely fine since each point's `.accessibilityValue` already states its `quadrantLabel`, but if the median values themselves are meaningful standalone data, consider surfacing them (e.g., via the chart's axis labels, already present).
- **`UsageInsightsView.swift` line 59–60** — `Text(insight.title)` (`.title3`, serif, semibold) reads as a card title, not a section header introducing further content; no trait needed, but double-check this is the intended semantic if more cards are added under a shared heading later.

---

## Assumptions

- Chart-level accessibility (`CostbyModelView`, `TicketToMergeView`) relies on a single summary `.accessibilityLabel` per chart rather than `AXChartDescriptor`/per-element navigation. This satisfies the minimum bar (every data point's information is present in the spoken summary) but a `AXChartDescriptor`-based implementation would let VoiceOver users navigate point-by-point with the Rotor. Not required for a PASS under the criteria used here.
- Verified only the six files under `Views/`; ViewModels and Models were read for context (e.g., `UsageInsight.swift`) but contain no UI/accessibility-relevant code.
