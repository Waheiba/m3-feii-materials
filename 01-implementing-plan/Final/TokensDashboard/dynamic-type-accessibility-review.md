# Dynamic Type Accessibility Review — TokensDashboard

**Overall Verdict: PASS**

Scope: all SwiftUI views under `TokensDashboard/TokensDashboard/Views/` (`ContentView`, `SummaryView`, `CostbyModelView`, `TicketToMergeView`, `TokensOutcomesView`, `UsageInsightsView`) plus `App/AppColors.swift`. No UIKit/AppKit representables, custom fonts, or hardcoded point sizes were found anywhere in the app — every `Text` element uses a semantic text style (`.subheadline`, `.caption`, `.footnote`, `.body`, or `Font.system(_ style:, design:, weight:)`, which is text-style-based and scales like any other style, unlike `Font.system(size:)`).

---

## ContentView.swift

No text elements. **PASS** (pure navigation shell).

## SummaryView.swift

| Element | Line | Font | Verdict |
|---|---|---|---|
| `Heading.title` | 22-23 | `.font(.system(.largeTitle, design: .serif, weight: .semibold))` | PASS — text-style based |
| `Heading.subtitle` | 24-25 | `.font(.subheadline)` | PASS |
| `InsightRow.headline` | 74-75 | `.font(.system(.title2, design: .serif, weight: .semibold))` | PASS |
| chevron `Image` | 77-78 | `.font(.footnote.weight(.semibold))` | PASS (decorative, paired with NavigationLink) |
| `InsightRow.detail` | 81-82 | `.font(.subheadline)` | PASS |

**Layout note (informational):** `InsightRow` uses an `HStack(alignment: .firstTextBaseline)` for the headline + chevron (lines 73-80). No `lineLimit` is applied, so wrapping is allowed — text will not be truncated at large sizes. No `@Environment(\.dynamicTypeSize)` check exists to switch this row to a vertical layout at accessibility sizes, but this is acceptable since the row already wraps rather than clips.

## CostbyModelView.swift

| Element | Line | Font | Verdict |
|---|---|---|---|
| `periodLine` | 15-16 | `.font(.subheadline)` | PASS |
| donut total (`totalDisplay`) | 43-44 | `.font(.system(.title, design: .serif, weight: .semibold))` | PASS |
| "total spend" | 45-46 | `.font(.caption)` | PASS |
| `SliceRow.name` | 73-74 | `.font(.body.weight(.medium))` | PASS |
| `SliceRow` share/MoM caption | 75-76 | `.font(.caption)` | PASS |
| `SliceRow.costDisplay` | 80-81 | `.font(.system(.body, design: .serif, weight: .semibold))` | PASS |

**Layout note (informational):** the donut chart has a fixed `.frame(height: 240)` (line 40) with text overlaid in its center (lines 42-48: title-sized total + caption). At larger accessibility text sizes, the overlaid text may visually crowd or exceed the donut's inner radius since the chart frame itself does not grow. Consider capping this overlay's dynamic type size range (e.g. `.dynamicTypeSize(...DynamicTypeSize.accessibility2)`) or verifying visually at AX sizes. The swatch `Circle` (line 71, fixed 10×10) is decorative only, so it is exempt.

**Chart note (informational):** Swift Charts renders its own internal chrome (axis labels, legends). This screen hides the legend (`.chartLegend(.hidden)`), so no Charts-owned text is visible here beyond the custom overlay, which is covered above.

## TicketToMergeView.swift

| Element | Line | Font | Verdict |
|---|---|---|---|
| `periodLine` | 16-17 | `.font(.subheadline)` | PASS |
| `subtitleLine` | 19-20 | `.font(.subheadline)` | PASS |

**Chart note (informational):** the line chart (`.frame(height: 320)`, line 56) includes Charts-framework-owned text: axis value labels (line 52), an axis label (line 45), and a legend (line 55). These are rendered by the Charts framework itself rather than by app code with an explicit `.font()` modifier, so this file's own code contains no failing pattern. However, Swift Charts' built-in chrome text has historically limited Dynamic Type responsiveness — flagged as an assumption/limitation rather than a fail, since it isn't controllable from this view's source.

## TokensOutcomesView.swift

| Element | Line | Font | Verdict |
|---|---|---|---|
| `periodLine` | 16-17 | `.font(.subheadline)` | PASS |
| "Top-left / bottom-right" caption | 19-20 | `.font(.subheadline)` | PASS |
| point annotation (`point.name`) | 48-49 | `.font(.caption)` | PASS |

**Chart note (informational):** same Swift-Charts caveat as `TicketToMergeView` applies to the axis labels (`chartXAxisLabel`/`chartYAxisLabel`, lines 58-59) and axis marks (line 61) inside the fixed `.frame(height: 320)` scatter chart (line 63). Point annotations use `.caption` (app-owned text) and pass.

## UsageInsightsView.swift

| Element | Line | Font | Verdict |
|---|---|---|---|
| `helperText` | 13-14 | `.font(.subheadline)` | PASS |
| `InsightCard.title` | 59-60 | `.font(.system(.title3, design: .serif, weight: .semibold))` | PASS |
| trend arrow `Image` | 63-64 | `.font(.footnote.weight(.semibold))` | PASS (exempt: `.accessibilityHidden(true)` at line 66) |
| `InsightCard.evidence` | 69-70 | `.font(.subheadline)` | PASS |
| `InsightCard.reviewPrompt` | 72-73 | `.font(.subheadline.weight(.medium))` | PASS |
| `InsightCard.periodLabel` | 74-75 | `.font(.caption)` | PASS |
| `InformationalState.message` | 93-94 | `.font(.subheadline)` | PASS |
| `CoverageNote` text | 106-107 | `.font(.caption)` | PASS |

No layout or overflow concerns — all content sits in a `ScrollView`, no fixed heights, no `lineLimit`.

---

## Assumptions

- Swift Charts' built-in chrome (axis labels, legends, axis marks) in `TicketToMergeView` and `TokensOutcomesView` is rendered by the framework, not by explicit app-level font modifiers. Its Dynamic Type behavior could not be fully verified from source alone — recommend a manual check at AX sizes (Settings → Accessibility → Larger Text) if precise chart-text scaling matters.
- No UIKit/AppKit views (`UILabel`, `NSTextField`, representables, etc.) exist in this codebase, so this review is SwiftUI-only.

## Summary

Every text element in the app uses a Dynamic-Type-aware font (semantic text styles or `Font.system(_ style:, ...)`). No hardcoded point sizes, no custom fonts without scaling, no `minimumScaleFactor` shrink-to-fit, and no truncating `lineLimit`. The only points worth a follow-up look are the two fixed-height chart overlays/chrome noted above — neither is a code-level failure, but both are worth a manual visual pass at large accessibility sizes.
