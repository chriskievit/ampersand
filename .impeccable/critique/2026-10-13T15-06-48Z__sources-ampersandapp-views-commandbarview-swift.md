---
target: Ampersand popover and window
total_score: 28
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 2
target_identity: "file:Sources/AmpersandApp/Views/CommandBarView.swift"
target_fingerprint: "sha256:2600d04159467264098befaabd79c27166ba24eea30796ec65245efd610fe13e"
target_path: Sources/AmpersandApp/Views/CommandBarView.swift
timestamp: 2026-10-13T15-06-48Z
slug: sources-ampersandapp-views-commandbarview-swift
---
Method: split assessment. A (design review) ran in this agent's context, which is itself a sub-agent with no detector output. B (detector + grep scan) ran in a separate, isolated sub-agent. I finished A's judgments (screenshots and source) before I read B's report.

# Ampersand: design critique

Date: 2026-10-13 · Plan Task 23 Step 4 · Procedure: Impeccable `critique.md`
Target: `Sources/AmpersandApp/Views/CommandBarView.swift` (popover, primary) and `Sources/AmpersandApp/Window/MainWindow.swift` (window, settings form, editor sheet).
Judged against: the direction contract `.impeccable/surfaces/sources-ampersandapp-views-commandbarview-swift.md`, spec section 4, `PRODUCT.md`, `craft-floor.md`, `operate.md`, and `ios.md` adapted to macOS (pointer and keyboard, menu bar, system text styles).
Evidence: 8 retina screenshots in `docs/design/screenshots/` (the window shots were taken while the window was not key), all source files under `Sources/AmpersandApp/**`, and contrast values measured from screenshot pixels.
Not repeated: findings already in `docs/design/audit-2026-10-13.md`. I cite an audit finding only where it bears on the contract, and I mark it `(audit P2-n)`.

---

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | The shape vocabulary works. But a command that exits cleanly (exit 0) shows as a red octagon, counts as "crashed", sets the menu bar attention dot, and sends an "unexpectedly" notification. |
| 2 | Match System / Real World | 3 | Terms are the user's own (port, pid, exit 1, signal 9). The "gave up after 5 restarts · exit 1" stamp reads well. |
| 3 | User Control and Freedom | 3 | Esc clears the filter, delete has Undo, and the editor guards unsaved changes. |
| 4 | Consistency and Standards | 2 | Ungrouped commands get a "No Group" header in the sidebar but none in the popover. The expanded row mixes two button sizes. The command line is right-aligned in the form. "Add" has three names (audit P3-3). |
| 5 | Error Prevention | 3 | Port conflicts are caught before start and offer two ways out. |
| 6 | Recognition Rather Than Recall | 3 | Shortcuts are only in tooltips. Return, the primary action, is not marked on any button. |
| 7 | Flexibility and Efficiency | 3 | The keyboard map is complete. But when the popover opens, nothing is selected, so the first Return does nothing. |
| 8 | Aesthetic and Minimalist Design | 3 | Calm and native. The noise is in the port-conflict row (6 buttons, the message said twice) and in a log tail spent on blank lines. |
| 9 | Error Recovery | 3 | "Port 8765 is in use by Python (pid 47680)" with "Start Anyway" and "Kill pid 47680" is a strong recovery. |
| 10 | Help and Documentation | 2 | The only help is the empty state line and the tooltips. Nothing in the popover shows that ↑↓ and ↩ work. |
| **Total** | | **28/40** | **Good** |

---

## Design Specificity Verdict

**LLM assessment.** This interface is authored, not templated. The parts that make it Ampersand and not "a menu bar app" are:

- the shape-first status vocabulary
- the exit stamp that stays in place of the metrics
- the filter field with its live "2 running" count
- the port-conflict recovery that names the process and its pid

It avoids the category default the contract rejects: there are no toggle-switch rows on a settings-style list. Nothing is custom-drawn, there is no hand-made glass, and SF Mono is used only for real command and log text.

It is not yet the Spotlight-driven object the THESIS describes. It is a filterable list that you can drive by keyboard once you know how, which is a quieter thing. The gaps are below.

**Contract check, clause by clause:**

| Clause | Delivered? | Evidence |
|---|---|---|
| THESIS: filter field with focus, arrows, Return to act | Partly | The filter has focus with a visible caret (`popover-dark.png`). Arrows work. Return only acts after you arrow to a row, because the popover opens with no selection and typing does not select the first match (audit P2-1). Keys only work while the filter has focus (audit P2-2). |
| OWN-WORLD: system popover, one text style, SF Mono only for real code, shape glyphs with secondary colour, accent only on pressables and selection, nothing custom-drawn | Mostly | One text style (`.body`) holds everywhere. Rank comes from `.medium` names, `.semibold` group headers, and `.secondary` metrics, with no `.caption` or `.footnote` anywhere (detector grep). Two misses: the selection is a 22% `.selection` wash that reads as a neutral grey card, so the accent appears nowhere in the popover (audit P2-4), and the octagon glyph is wider than the circles, so the names do not line up. |
| STORY: glance, see what runs and what died with its exit stamp, act with one key, close | Partly | Glance and see: yes. "What died": a clean exit 0 is drawn as died (new, P1 below). "Act with one key": not on open. |
| FIRST VIEWPORT: ~360 pt, filter + count, group headers, rows with glyph/name/:port/CPU/mem/uptime, **selected row expanded with last 5 log lines**, footer with + Add, Open Ampersand, Quit and Stop N Processes | No | Width, header, rows, and metrics match. The selected and expanded row is missing at open (`popover-dark.png`: nothing is expanded). The footer's Quit label is cut to "Quit and Stop 2 Proces…". Ungrouped rows `migrate` and `caffeinate` appear under "Storefront". |
| FORM / signature interaction: arrow to a row and it expands in place to a live log tail, Return starts or stops; one `.snappy` spring, crossfade under Reduce Motion | Yes, with flaws | The expansion is real and in place (`popover-dark-expanded.png`). The tail is live (`TimelineView`, `recentLines`). The `.snappy` spring is used. Flaws: the 5-line budget is spent on blank and indented lines (the tail shows 3 useful lines). Reduce Motion snaps instead of crossfading (audit P3-1). |

**Verdict: the contract is partially delivered.** OWN-WORLD and FORM hold. FIRST VIEWPORT fails on its defining element: the expanded selected row and Return as the primary action at open. Because of that, THESIS and STORY only hold after the user's first arrow key. All of this can be fixed without changing the direction. The fix batch below closes it.

**Deterministic scan (Assessment B).**

- `impeccable detect --json Sources/AmpersandApp` returned `[]` with exit 0. The same happened for `Views/` and `Window/`. The detector has no Swift mode: its `--help` lists only HTML, CSS, JSX, TSX, and URLs. So the exit 0 means "Swift was not analysed", not "clean". No findings, no false positives.
- The fallback grep scan agrees with A:
  - no hard-coded font sizes in SwiftUI
  - `design: .monospaced` only at the 4 code and log sites (`CommandForm.swift:25`, `EnvEditor.swift:16`, `ProjectImportSheet.swift:71`, `ExpandedRow.swift:59`)
  - no hex colours, no `Material`, no `.shadow`
  - one opacity hack: `CommandRow.swift:49` `.selection.opacity(0.22)`
  - `.tertiary` at `CommandRow.swift:88` and `ExpandedRow.swift:54`
  - the popover footer buttons have no `lineLimit` (`CommandBarView.swift:133-136`)
- The scan also caught something A only saw by eye: `ExpandedRow.swift:83` applies `.controlSize(.small)` to the actions row only. That is why the port-conflict buttons render larger.

**Visual overlays:** none. Browser injection does not apply to a native SwiftUI target, so no overlay is available.

---

## Overall Impression

This is a native, quiet popover that a Mac user will trust on sight, and the status language is the best thing in it. Its weak spot is the moment it was designed around. Opening the popover should land on an expanded row with Return ready, as in Spotlight. Today it lands on a flat list that waits for an arrow key.

The single biggest opportunity is to select a row on open (the crashed row first, otherwise the last selection, otherwise the first row). That one change delivers FIRST VIEWPORT, makes Return act at once, and puts the "memorable moment" (the crashed octagon and its stamp) directly in front of the user.

## What's Working

1. **State is shape, not colour.** `StatusGlyph` uses filled, dashed, octagon, and hollow shapes. In `popover-dark.png` you can tell `worker` (gave up) from `caffeinate` (stopped) in greyscale. The stamp "gave up after 5 restarts · exit 1" replaces the metrics, so the row says why, not only that.
2. **Port-conflict recovery is specific.** "Port 8765 is in use by Python (pid 47680)." followed by "Start Anyway" and "Kill pid 47680" names the problem, the culprit, and two ways out. This is principle 2 ("failure is loud") done right.
3. **Typographic restraint.** The whole popover is one text style ranked by weight and secondary colour. Tabular figures keep CPU and memory steady. The log tail is the only SF Mono, and it is real output.

## Priority Issues

**[P1] A clean exit (exit 0) is shown and announced as a crash**

- **Why it matters:**
  - `CommandStatus.kind` maps every `.exited` to `.exited` (`AmpersandCore/Supervision/CommandStatus.swift:30`).
  - `StatusGlyph` draws `.exited` as a red `xmark.octagon.fill` (`StatusGlyph.swift:37, 46`).
  - `StatusText.stateWord` says "crashed".
  - `attentionCount` (`AppModel.swift:115`) counts it, so the menu bar icon shows the attention dot.
  - `NotificationService.swift:34-35` posts "web stopped unexpectedly (exit 0)".
  - So any command that finishes on purpose (a migration, `caffeinate -t 3600`, a build) raises the one alarm the product keeps for failure. That breaks principle 2 and the contract's "memorable moment" (the octagon must mean something died).
- **Fix:** map a clean exit to the quiet state. Keep the stamp ("exit 0 · 14:02") as the record. Do not notify.
- **Suggested command:** `/impeccable harden`

**[P1] FIRST VIEWPORT has no selected, expanded row, so Return does nothing on open**

- **Why it matters:** the contract's first viewport and its "primary action is Return on the selection" both depend on there being a selection. `CommandBarView.swift:30-36` resets the filter and focuses it on open, but never sets `popoverSelection`. In `popover-dark.png`, nothing is expanded. The user has to press ↓ before any key acts. That turns the Spotlight thesis into "a list with shortcuts". It also hides the crashed row's log tail, which is exactly what the user opened the popover to see.
- **Fix:** on open, select the first row that needs attention (crashed, gave up, failed, or port conflict). If none, keep the previous selection when it is still visible. Otherwise select the first row. Also select the first match while filtering (audit P2-1). Also move the key handler to the container (audit P2-2).
- **Suggested command:** `/impeccable harden`

**[P2] The footer's Quit label truncates at 360 pt**

- **Why it matters:** `popover-dark.png` shows "Quit and Stop 2 Proces…". The label exists to warn that quitting stops processes, and it loses its last word. From the screenshot, the measured need is about 16 + 52 (Add) + 16 + 105 (Open Ampersand) + 9 + 170 (Quit…) + 16 ≈ 384 pt, which is more than 360. With "Processes" (plural) and a two-digit count it gets worse. Both buttons have no `lineLimit` (`CommandBarView.swift:133-136`). A different label length or a larger text size could wrap the label into a two-line footer.
- **Fix:** use `ViewThatFits` with "Quit and Stop 2 Processes", then "Quit and Stop 2", then "Quit", each `.lineLimit(1)`. Give it `.layoutPriority(1)` and put the full title in `.help`. Hide the Add menu's chevron to win back about 10 pt. Note that the header already says "2 running", so the short form still makes sense.
- **Suggested command:** `/impeccable layout`

**[P2] In the popover, ungrouped commands look like members of the group above**

- **Why it matters:** `CommandBarView.swift:107-110` draws a header only for grouped sections. In `popover-dark.png`, `migrate` and `caffeinate` (ungrouped) sit under "Storefront" with no break. The window labels them "No Group" (`Sidebar.swift:103-105`, `window-log-dark.png`). So the two surfaces disagree, and the popover misreports membership. That matters because ⌥↩ (Start/Stop Group) acts on group membership.
- **Fix:** draw the same "No Group" header in the popover when the ungrouped section is not the only visible section. This is a small departure from the wording of spec 4.2 ("under no header"). The alternative is a `Divider()`, but the header matches the window.
- **Suggested command:** `/impeccable clarify`

**[P2] The window's settings form reads code right-aligned and hides fields behind "More"**

- **Why it matters:**
  - In `window-settings.png`, the Command field is a grouped-form `TextField`, so its value is right-aligned. The shell line `printf '\e[31mred…' ; sleep 600` wraps with a ragged left edge, which makes code hard to read. The same happens in the editor sheet (`editor-chips.png`).
  - In the window's Settings tab, the form is passed `expanded: true` but still wraps half its fields in a "More" disclosure. That creates a "More" row followed by rows without separators.
  - The Environment editor sits in a trailing column that starts mid-row (x ≈ 374 pt). That is a third column edge in one form.
  - Right-aligned Name and Group values are normal on the platform. Right-aligned code is not.
- **Fix:**
  - Give the command its own section with a hidden label and `.multilineTextAlignment(.leading)`.
  - Render the "More" fields without the disclosure when the form is the window pane.
  - Put the Environment label above a full-width editor.
- **Suggested command:** `/impeccable layout`

## Persona Red Flags

**Alex (Power User):**
- Opens the popover and presses ↩ to restart the crashed `worker`. Nothing happens, because nothing is selected.
- Types `mig` and presses ↩. Still nothing (audit P2-1).
- Tabs to a button and presses ⌘R. Ignored, because the key handler is on the filter field only (audit P2-2).
- No button shows which one ↩ will press. The `.help("Return")` tooltip needs a hover, and a keyboard user never hovers.

**Sam (Accessibility):**
- The sidebar names measure 1.85:1 (light) and 2.74:1 (dark) against the sidebar in the non-key captures. Even the capture with coloured traffic lights measures 3.0:1. The `:port` next to each name measures 3.8 to 7.3:1. So the secondary text is more legible than the primary text, and the hierarchy is inverted for low-vision users.
- "stopped" in the dark popover measures 3.1:1 (audit P2-6).
- The port-conflict row has 6 buttons in 2 sizes, which is a long Tab sequence.

**Riley (Stress Tester):**
- `caffeinate -t 5` exits 0 after 5 s. Riley gets a red octagon, a menu bar dot, and a notification saying it "stopped unexpectedly".
- With a port conflict, Riley presses Start, sees "Start" next to "Start Anyway", presses Start again, and gets the same conflict.
- A Vite server's tail shows a blank line and indentation in place of two real lines.

## Minor Observations

- **Glyph column drift:** `xmark.octagon.fill` is about 1.5 pt wider than `circle.fill`. The names `worker` and `migrate` start at x ≈ 40.5 pt, while `api` and `caffeinate` start at 39 pt (`popover-dark.png`, and the same in the sidebar). Give the glyph a fixed frame.
- **Port conflict said twice:** the selected row shows "port 8765 in use by Python" in the trailing slot and the full sentence below it (`popover-port-conflict.png`). Drop the trailing copy when the row is expanded.
- **Duplicate start:** the conflict row shows both "Start" and "Start Anyway". While a conflict is active, Start only reproduces the conflict, so hide it.
- **Return target not marked:** none of the expanded row's four buttons uses the accent. Making the Return action `.borderedProminent` marks the default action. It also gives the accent the job the contract assigns it ("pressables and selection"), which the 22% selection wash does not do.
- **Log tail budget:** `recentLines` (`CommandRuntime.swift:38-42`) counts blank lines. In `popover-dark-expanded.png`, Vite's blank line uses one of the 5 slots.
- **Editor sheet height:** `CommandEditorSheet.swift:56` (`minHeight: 420, idealHeight: 560`) leaves about 45% of the sheet empty while "More" is collapsed (`editor-chips.png`).
- **Detected chips:** these are native `.bordered` buttons, which is acceptable. They flow from the trailing column of a `LabeledContent`, so they line up with neither the label nor the field. Consider letting them run full width under the command.
- **Light popover:** the white bloom on the right of `popover-light.png` is Liquid Glass refracting the desktop. It is not an app defect.
- **Window toolbar:** six icon-only buttons in two clusters. The trash icon for Clear Log is already audit P3-6. Apart from that, the toolbar is platform-correct.

## Questions to Consider

- If the popover opened on the crashed row, already expanded with its last error lines, would the menu bar dot need a separate "what happened" step at all?
- Does the Quit button belong in the footer at all when ⌘Q exists? What if the footer held only "+ Add" and "Open Ampersand", and Quit moved into a ⋯ menu with Settings?
- Should a clean exit leave any mark (a quiet `exit 0 · 14:02` stamp on a hollow circle), or reset to "stopped"? The contract says nothing silently resets. That argues for keeping the stamp.
