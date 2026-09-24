# Dynamic Type Audit — TokensDashboard

Scope: all SwiftUI view files in `TokensDashboard/Views/` (`ContentView.swift`,
`SummaryView.swift`, `CostbyModelView.swift`, `TicketToMergeView.swift`,
`TokensOutcomesView.swift`, `UsageInsightsView.swift`). Verified by reading source only — no build
or on-device Dynamic Type testing was performed as part of this audit.

## Verdict: FAIL

Every `Text` element in the app correctly uses a scalable text style — there are **no hardcoded
point sizes** (`.system(size:)`) anywhere in the view layer, which is the most common way this
check fails. The single violation is a layout one: a chart overlay's text sits inside a
fixed-height frame that will clip at large accessibility type sizes.

---

## Passing elements

All of the following use semantic text styles or the scaling `Font.system(_:design:weight:)`
overload (first argument is a `Font.TextStyle`, not a point size), so they track the user's
preferred content size category automatically.

| File | Line(s) | Element | Font spec |
|---|---|---|---|
| `CostbyModelView.swift` | 15–17 | period line | `.font(.subheadline)` |
| `CostbyModelView.swift` | 44 | donut total display | `.font(.system(.title, design: .serif, weight: .semibold))` |
| `CostbyModelView.swift` | 46 | "total spend" caption | `.font(.caption)` |
| `CostbyModelView.swift` | 74 | model name (`SliceRow`) | `.font(.body.weight(.medium))` |
| `CostbyModelView.swift` | 76 | share/MoM caption | `.font(.caption)` |
| `CostbyModelView.swift` | 81 | cost display | `.font(.system(.body, design: .serif, weight: .semibold))` |
| `SummaryView.swift` | 22–23 | heading title | `.font(.system(.largeTitle, design: .serif, weight: .semibold))` |
| `SummaryView.swift` | 24–26 | heading subtitle | `.font(.subheadline)` |
| `SummaryView.swift` | 74–75 | insight headline | `.font(.system(.title2, design: .serif, weight: .semibold))` |
| `SummaryView.swift` | 78 | chevron icon | `.font(.footnote.weight(.semibold))` (decorative, not text) |
| `SummaryView.swift` | 81–83 | insight detail | `.font(.subheadline)` |
| `TicketToMergeView.swift` | 16–18 | period line | `.font(.subheadline)` |
| `TicketToMergeView.swift` | 19–21 | subtitle line | `.font(.subheadline)` |
| `TokensOutcomesView.swift` | 16–18 | period line | `.font(.subheadline)` |
| `TokensOutcomesView.swift` | 19–21 | quadrant legend line | `.font(.subheadline)` |
| `TokensOutcomesView.swift` | 48–50 | point-name annotation | `.font(.caption)` |
| `UsageInsightsView.swift` | 22–24 | disclaimer line | `.font(.subheadline)` |
| `UsageInsightsView.swift` | 53–55 | "no qualifying changes" | `.font(.subheadline)` |
| `UsageInsightsView.swift` | 59–61 | "insufficient data" | `.font(.subheadline)` |
| `UsageInsightsView.swift` | 76–79 | coverage note line | `.font(.caption)` |
| `UsageInsightsView.swift` | 101–102 | card title | `.font(.system(.title2, design: .serif, weight: .semibold))` |
| `UsageInsightsView.swift` | 105 | trend icon | `.font(.footnote.weight(.semibold))`, also `.accessibilityHidden(true)` — exempt |
| `UsageInsightsView.swift` | 110–111 | evidence text | `.font(.body)` |
| `UsageInsightsView.swift` | 112–114 | reporting period label | `.font(.caption)` |
| `UsageInsightsView.swift` | 115–117 | review prompt | `.font(.subheadline)` |

`ContentView.swift` contains no text elements (it only composes `SummaryView` inside a
`NavigationStack`) — nothing to evaluate there.

No `.minimumScaleFactor`, no `.lineLimit(1)` truncation on user-facing copy, and no custom named
fonts were found anywhere in the view layer.

---

## Failing elements

### 1. Donut chart overlay text can clip inside a fixed-height frame — `CostbyModelView.swift:40–48`

```swift
.frame(height: 240)
.overlay {
  VStack(spacing: 2) {
    Text(costByModelViewModel.totalDisplay)
      .font(.system(.title, design: .serif, weight: .semibold))
    Text("total spend")
      .font(.caption)
      .foregroundStyle(.secondary)
  }
}
```

- The chart is pinned to a fixed `.frame(height: 240)`, and the total/"total spend" `Text` pair is
  overlaid on top of it, centered inside the donut's inner radius (`0.66` of 240pt ≈ 158pt usable
  diameter).
- The font specs themselves are correct (`.title` and `.caption` both scale), which is exactly the
  problem: at larger accessibility sizes (e.g. AX3–AX5) the combined height and width of `.title` +
  `.caption` text will exceed the fixed inner-circle space, causing the total figure and/or the
  "total spend" caption to clip or overlap the donut ring.
- **Fix:** don't fight the frame — let the overlay content dictate a minimum, or drop the fixed
  height in favor of a size that responds to type size. Two concrete options:
  - Wrap the chart's height in a `@ScaledMetric`, e.g.
    `@ScaledMetric(relativeTo: .title) private var chartHeight: CGFloat = 240`, then use
    `.frame(height: chartHeight)`.
  - Or clamp the overlay text with `.dynamicTypeSize(...up to: .accessibility2)` on the `VStack`
    overlay specifically (not the whole screen) so the donut stays legible while the rest of the
    screen — which is in a `ScrollView` — keeps scaling freely.

---

## Layout notes (informational — not failures)

- **`CostbyModelView.swift:40` / `TicketToMergeView.swift:56` / `TokensOutcomesView.swift:63`** —
  all three detail screens pin their `Chart` to a fixed `.frame(height:)` (240/320/320pt). This is
  standard practice for chart plot areas and is not a Dynamic Type violation by itself, but Swift
  Charts' own axis labels, legends, and axis titles (e.g. `chartYAxisLabel`, `chartLegend`,
  `AxisValueLabel`) render as text whose exact scaling behavior isn't verifiable from source alone
  — see Assumptions below.
- **`SummaryView.swift:73` (`InsightRow`)** — the headline `Text` + `Spacer` + chevron `Image` sit
  in a single `HStack(alignment: .firstTextBaseline)`. At accessibility sizes the headline can wrap
  to multiple lines; there's no `@Environment(\.dynamicTypeSize)` check to switch this row to a
  vertical layout. Each row is in a `ScrollView` via the parent `SummaryView`, so content won't be
  clipped, but the chevron may end up vertically misaligned against a wrapped multi-line headline.
- No view in this app uses `@ScaledMetric`, `ViewThatFits`, or `@Environment(\.dynamicTypeSize)`.
  None of the fixed-size decorative elements found (the 10×10 color swatch `Circle` in
  `CostbyModelView.swift:71`, SF Symbol icons) carry enough visual weight to require scaling, so
  this is not flagged as a failure.
- All six views are hosted in a `ScrollView`, so vertical growth of scaling text is generally safe
  except where called out above.

## Assumptions

- Swift Charts' built-in text (axis labels, legends, chart axis titles via `chartYAxisLabel`,
  `chartXAxisLabel`, `AxisValueLabel`) was not overridden with any custom font in any of the three
  chart screens, so it should inherit the framework's default Dynamic Type behavior. This could not
  be independently confirmed from source and would need on-device verification at larger type
  sizes.
- `KPIFormat.swift` and other view-model formatting helpers were not read as part of this audit
  since they produce plain `String` values, not font/text-style decisions — the assumption is that
  no view model is truncating or pre-formatting text in a way that would defeat scaling.
