---
version: 1
slug: "ampersand-views-commandbarview-swift"
primary_target: "Ampersand/Views/CommandBarView.swift"
related_targets: ["Ampersand/Views/MainWindow.swift"]
---

# Surface brief: Ampersand popover and window

Scope: the menu bar popover (primary) and the main window (log, settings, editor). Visitor mode: Operate.

Audience and job: one developer mid-workday; glance, act in seconds, leave. Proof is live process state: status, exit stamps, log tail, CPU/memory, uptime. Constraints: native macOS 26, SwiftUI, Apple HIG; full spec in docs/superpowers/specs/2026-10-13-ampersand-design.md section 4.

Memorable moment: a crashed command never resets silently; its octagon and exit stamp wait in the popover until acted on.

Unresolved: final form of the env editor (iterate after first build).

## Direction contract

THESIS: Ampersand is driven like Spotlight: a filter field with focus, arrow keys, Return to act. It refuses the category default of toggle-switch rows on a settings-style list.

OWN-WORLD: The system's own Liquid Glass popover, SF Pro in one text style, SF Mono only for real command and log text, SF Symbols status glyphs whose shape carries state (filled, dashed, octagon, hollow) and whose system colour is secondary. The accent colour appears only on pressables and selection. Nothing custom-drawn.

STORY: Open with a glance, see what runs and what died with its exit stamp, act with one key, close. The window exists for full logs and editing only.

FIRST VIEWPORT: About 360 pt wide. Filter field with focus at the top, a "4 running" count trailing it. Group headers with rows beneath (glyph, name, :port, tabular CPU/memory, uptime). The selected row is expanded with its last 5 log lines and actions. The footer holds + Add, Open Ampersand, and Quit and Stop N Processes. The primary action is Return on the selection.

FORM: Command Bar (Spotlight quick-actions lineage), assigned at position 4 of the grounded list on re-roll 1, seed key f3019e17. Signature interaction: arrow to a row and it expands in place to a live log tail, with Return to start or stop. Motion grammar: one system .snappy spring for expand and status change, crossfade under Reduce Motion.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
