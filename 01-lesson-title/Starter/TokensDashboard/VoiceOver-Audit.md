# VoiceOver Accessibility Audit — Tokens Dashboard

## Verdict: FAIL

Scope: source-code review of every `View` in `TokensDashboard/TokensDashboard/Views/` (`ContentView.swift`, `SummaryView.swift`, `CostbyModelView.swift`, `TicketToMergeView.swift`, `TokensOutcomesView.swift`, `UsageInsightsView.swift`) against Apple's VoiceOver nutrition-label criteria: missing labels, non-human-readable labels, missing/incorrect traits, inaccessible images, and (for UIKit/AppKit) missing `isAccessibilityElement`. The app is pure SwiftUI, so Criterion 5 does not apply. No code was changed; no live VoiceOver pass was run — this is a static analysis.

The failure is narrow: two custom section/card titles are styled visually as headings (large/bold serif text introducing a block of content) but never carry `.accessibilityAddTraits(.isHeader)`, so VoiceOver's Headings rotor cannot jump to them. Everything else in the app — chart accessibility (including a genuinely good per-data-point pattern in `TokensOutcomesView`), decorative icon handling, and row/card grouping — is implemented correctly.

---

## Failing elements

### 1. `SummaryView.swift:22` — page title missing Header trait

```swift
Text(title)
  .font(.system(.largeTitle, design: .serif, weight: .semibold))
```

`Heading` (lines 16–31) renders "Token's Dashboard Summary" as a `.largeTitle` serif/semibold `Text` at the top of the screen's content — `.navigationTitle("")` is deliberately empty (line 53), so this custom text *is* the page's visual title. It has no `.accessibilityAddTraits(.isHeader)`, so it won't appear in VoiceOver's Headings rotor and is announced as plain static text.

**Fix:** add the trait to the title only (not the subtitle):
```swift
Text(title)
  .font(.system(.largeTitle, design: .serif, weight: .semibold))
  .accessibilityAddTraits(.isHeader)
```

### 2. `UsageInsightsView.swift:101` — card title missing Header trait

```swift
Text(insight.title)
  .font(.system(.title2, design: .serif, weight: .semibold))
```

`InsightCardView` (lines 87–124) styles `insight.title` as a `.title2` serif/semibold heading at the top of each card. The card is not interactive (no `Button`/`NavigationLink`), so it's a genuine section header, not a control. Because the card already uses `.accessibilityElement(children: .combine)` + a fully composed `.accessibilityLabel` (lines 121–122), the title `Text` never surfaces as its own node — the trait has to go on the combined container instead, or the card won't show up in the Headings rotor at all.

**Fix:** add the trait to the already-present container modifiers:
```swift
.accessibilityElement(children: .combine)
.accessibilityAddTraits(.isHeader)
.accessibilityLabel("\(insight.category.rawValue.capitalized): \(insight.evidence). \(insight.reportingPeriodLabel). \(insight.reviewPrompt)")
```

---

## Passing elements

### `ContentView.swift`
No interactive elements, images, or custom views — just `NavigationStack { SummaryView() }`. Nothing to audit.

### `SummaryView.swift`
- `NavigationLink(value:) { InsightRow(...) }` (lines 43–46): standard framework control — exempt, correct traits by default.
- `InsightRow` (lines 68–91): `.accessibilityElement(children: .combine)` + explicit `.accessibilityLabel("\(insight.headline) \(insight.detail)")` (lines 88–89) gives the whole tappable row one meaningful, human-readable label. Criterion 1 pass.
- `Image(systemName: "chevron.right")` (line 77): purely decorative disclosure chevron; absorbed into `InsightRow`'s combined/overridden label, so it is never announced on its own. Criterion 4 pass.
- `Text(subtitle)` (line 24), `Divider()`: plain static/decorative content — exempt.

### `CostbyModelView.swift`
- `donut` (Chart, lines 28–51): `.accessibilityLabel("Donut chart of month to date cost by model, total \(...)")` (line 50) gives the whole chart a single meaningful summary. Criterion 1 pass.
- `SliceRow` (lines 63–86): `.accessibilityElement(children: .combine)` (line 84) reads the swatch/name/share/change/cost as one row. Not interactive, no traits required. Criterion 3 n/a.
- `Circle()` swatch (lines 69–71): a `Shape`, not an `Image` — purely decorative color key alongside a named row; not independently meaningful. Exempt.
- `Text(periodLine)` (line 15): static — exempt.

### `TicketToMergeView.swift`
- `lines` (Chart, lines 33–58): `.accessibilityLabel(accessibilitySummary)` (line 57), where `accessibilitySummary` (lines 60–65) narrates the chart plus every point's `detailDisplay`. Criterion 1 pass — good pattern for a multi-series line chart with no per-point marks labels.
- `Text(periodLine)`, `Text(subtitleLine)`: static — exempt.

### `TokensOutcomesView.swift`
- `PointMark` (lines 41–54): each mark carries its own `.accessibilityLabel(point.name)` and `.accessibilityValue("\(point.detailDisplay) · \(point.quadrantLabel)")` (lines 52–53) — correct per-data-point chart accessibility, letting VoiceOver users navigate individual scatter points via the chart's data-point rotor. Criterion 1 pass, best pattern in the app.
- `RuleMark` median guides (lines 34–39): decorative reference lines, no standalone meaning — exempt.
- Static `Text` elements: exempt.

### `UsageInsightsView.swift`
- `Image(systemName: iconName)` trend arrow (lines 104–108): explicitly `.accessibilityHidden(true)` (line 107); the same information ("increased"/"decreased") is already carried in `insight.evidence`'s text. Criterion 4 pass.
- `InsightCardView` label composition (lines 121–122): combines category, evidence, reporting period, and review prompt into one human-readable label. Criterion 1 pass (Header trait aside — see Failing elements above).
- Top explanatory `Text`, `coverageNote` lines (lines 66–82), empty/no-data state `Text`s: static — exempt.

---

## Recommendations (do not affect verdict)

- **Chart overlay double-announcement risk (`CostbyModelView.swift:41-49`):** the "total spend" value/caption is rendered via `.overlay` on top of `donut`'s `Chart`, while the whole `donut` already carries one `.accessibilityLabel` (line 50) that includes the total. Verify with a live VoiceOver pass that the overlay `Text` isn't also announced separately (would duplicate the total). If it is, add `.accessibilityHidden(true)` to the overlay's `VStack` (lines 42–48) since the label already states the total.
- **Custom actions:** not applicable — no `.swipeActions`, editing gestures, or long-press menus exist anywhere in the app.
- **Additional traits:** not applicable — no segmented controls, live-updating counters, or custom search fields exist.
- **Reading order:** no `ZStack`/absolute-position layouts whose visual order diverges from source order were found; no action needed.

## Assumptions

- `UsageInsightsView.swift:122` — `insight.category.rawValue.capitalized` renders `UsageInsightCategory.modelMix` (raw value `"modelMix"`) as **"Modelmix"** (Swift's `.capitalized` only uppercases the first letter of a single-word string; it does not split camelCase), so VoiceOver announces "Modelmix: …" instead of "Model Mix: …". This doesn't cleanly match any of the five listed non-human-readable-label patterns (it's not camelCase/snake_case/UUID/etc. — if anything it collapses camelCase into one run-on word), so it is **not counted toward the verdict**, but it is a real spoken-clarity defect worth a one-line fix (e.g. a `displayName` computed property on `UsageInsightCategory` instead of deriving from `rawValue`).
- Assumed Swift Charts' default behavior (no per-mark `.accessibilityLabel`) renders `SectorMark`/`LineMark` content as non-individually-accessible, so `donut` (`CostbyModelView`) and `lines` (`TicketToMergeView`) needing only one container-level `.accessibilityLabel` is correct and complete. This is consistent with `TokensOutcomesView`'s contrasting use of per-`PointMark` labels, which is the right choice there because individual scatter points are independently meaningful.
