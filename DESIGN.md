---
name: Ampersand
description: The `&` you put after a command, made visible. A native macOS 26 menu bar app that keeps long-running commands alive, visible and one key away.
colors:
  # Reference values only. The normative source is the SwiftUI/AppKit semantic colour named in the prose;
  # views never contain a hex. Light-appearance values shown; dark values are in .impeccable/design.json.
  accent: "#007AFF"
  status-running: "#34C759"
  status-transition: "#FF9500"
  status-failed: "#FF3B30"
  health-badge: "#FFCC00"
  label: "#000000D9"
  secondary-label: "#00000080"
  separator: "#0000001A"
  icon-prompt-green: "#4CD964"
  icon-graphite: "#292D33"
typography:
  body:
    fontFamily: "SF Pro (system .body style), -apple-system, system-ui"
    fontSize: "13px"
    fontWeight: 400
  body-emphasis:
    fontFamily: "SF Pro (system .body style), -apple-system, system-ui"
    fontSize: "13px"
    fontWeight: 500
  section-label:
    fontFamily: "SF Pro (system .body style), -apple-system, system-ui"
    fontSize: "13px"
    fontWeight: 600
  code:
    fontFamily: "SF Mono (system .body style, design .monospaced), ui-monospace, monospace"
    fontSize: "13px"
    fontWeight: 400
  numeric:
    fontFamily: "SF Pro (system .body style), -apple-system, system-ui"
    fontSize: "13px"
    fontWeight: 400
    fontFeature: "tnum"
rounded:
  selection: "6px"
  notice: "8px"
spacing:
  hairline: "2px"
  xs: "6px"
  sm: "8px"
  notice: "10px"
  md: "12px"
  lg: "16px"
  xl: "24px"
components:
  command-row:
    textColor: "{colors.label}"
    padding: "6px 8px"
  command-row-selected:
    backgroundColor: "{colors.accent}"
    rounded: "{rounded.selection}"
    padding: "6px 8px"
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "#FFFFFF"
  popover-banner:
    textColor: "{colors.label}"
    rounded: "{rounded.notice}"
    padding: "{spacing.notice}"
  suggestion-chip:
    textColor: "{colors.label}"
  popover:
    width: "360px"
---

# Design System: Ampersand

## Overview

**Creative North Star: "The System's Own Command Bar"**

Ampersand looks like it shipped with macOS 26. The popover is a Spotlight-style command bar on the system's Liquid Glass popover material; the window is a System Settings-style `NavigationSplitView`. Nothing is custom-drawn: system text styles, semantic system colours, system materials, SF Symbols and stock controls carry the whole interface. Identity comes from behaviour (filter field with focus, arrow keys, Return to act) and from one fixed status-glyph vocabulary, never from a palette or a typeface.

Density is that of a native list: one text style, ranked by weight and secondary label colour, tabular figures for every live number. Success is quiet (a filled green circle, a hollow circle for a clean finish); failure is the only thing that waits for attention (a red octagon with its exit stamp, preselected when the popover opens).

**The Ambient Job (philosophy).** The `&` sends a job to the background so you can stop thinking about it, and the popover follows that stance. Service catalogues show an inventory with every number on every row; Ampersand stays quiet and answers intent. Four principles, applied without hiding anything a user needs:
1. *Silence is the success state.* A healthy row shows its uptime; CPU and memory appear on the row only when high, and always in the expanded row.
2. *Attention is earned by change.* Failures keep their stamp and are selected on open. Do not push this into extra summaries or digests: the popover stays succinct.
3. *Intent first, inventory second.* The filter field is also the prompt: text that matches no command is offered as a new one.
4. *Shell behaviour, native look.* Job specs (`%1`), `&` and Return come from the shell; mono type, green-on-black and terminal styling do not.

**The Native First Rule.** The #1 design driver is native macOS feel, with System Settings as the reference for the window. When a native choice and an Impeccable choice differ, ask the user before building; do not decide either way alone. Recorded Impeccable choice the user approved: paste-suggestion chips in the command form.

**Key Characteristics:**
- System text styles, semantic system colours and system materials only; no hex, no fixed font size, no custom shadow in views.
- State is carried by glyph shape first; colour is secondary and lives only in the glyph.
- The accent colour appears only on pressables and on selection.
- SF Mono only for real code and data: command lines, log lines, environment names and values.
- Layout never moves under the pointer: hover affordances are always laid out and shown by opacity.

## Colors

The palette is the system's: adaptive semantic colours that follow Light/Dark, Increase Contrast and Reduce Transparency. Frontmatter hex values are references for tooling; code names the semantic colour.

### Primary
- **System Accent** (`Color.accentColor`): the prominent action in an expanded row (Start / Stop / Start Again, `.borderedProminent`) and the selection highlight. Nowhere else.

### Secondary
- **Running Green** (`.green`): the filled-circle glyph for a running command.
- **Transition Orange** (`.orange`): the dashed-circle glyph for starting, stopping and restarting (backoff).
- **Failure Red** (`.red`): the octagon glyph for exited, gave up and couldn't start.
- **Health Yellow** (`.yellow`): the small warning-triangle badge on a running glyph whose health check fails.

### Neutral
- **Label** (`.primary` / `labelColor`): names, messages, footer controls, log text without ANSI colour.
- **Secondary Label** (`.secondary`): metrics, exit stamps, ports, state words, group headers, the popover log tail, notice and info icons, form footers, the stopped/finished glyph.
- **Separator** (`Divider()`): between popover header, list and footer; under the window notice band.
- **Tertiary Fill** (`.fill.tertiary`): the popover inline banner background only.
- **Text Background** (`textBackgroundColor`): the full log view.

### App icon colours (icon only, never in the UI)
- **Prompt Green** and **Graphite**: the Liquid Glass icon's glyph layer and automatic-gradient fill.

### Named Rules
**The Shape Before Colour Rule.** Every status is readable in greyscale: filled, dashed, octagon, hollow. Colour only confirms. The menu bar icon is a template image, so its attention signal is a dot (shape), never red.

**The Accent Is a Pressable Rule.** The accent colour marks things you can press and the current selection. Status colour never leaks into text, rows or backgrounds.

**The Log Keeps Its Colours Rule.** ANSI colours in log output are content: they render, mapped to the nearest system colour (`systemRed`, `systemGreen`, `labelColor` …) so they adapt to appearance. Dim is 60 % alpha.

## Typography

**Body Font:** SF Pro via the system `.body` text style (13 pt on macOS; never hard-coded)
**Label/Mono Font:** SF Mono via `.system(.body, design: .monospaced)`

**Character:** One system voice at one size. Hierarchy comes from weight and label colour, the way a Finder sidebar or System Settings list does it.

### Hierarchy
- **Body** (regular, `.body`): messages, buttons, metrics, stamps, form values.
- **Body emphasis** (medium, `.body`): command names in popover rows.
- **Section label** (semibold, `.body`, secondary colour): popover group headers and "No Group".
- **Code** (regular, `.body` monospaced): command field, log tail and full log, env names/values, import-sheet command lines.
- **Numeric** (`.monospacedDigit()`): every live or counted number (CPU %, memory, uptime, `:port`, "N running", stamps) so values update in place without jitter.
- Window chrome (navigation title/subtitle, `Form` section headers, `.headline` sheet title) uses whatever the system control supplies; do not restyle it.

### Named Rules
**The One Text Style Rule.** The popover uses `.body` only. Rank by weight (regular / medium / semibold) and `.secondary`, never by size.

**The Mono Is Data Rule.** SF Mono is for text a shell or process produced or will consume. Never for labels, headings, or a "technical" look.

## Layout

**Popover (command bar).** Fixed 360 pt wide, height sizes to rows up to a 480 pt scroll limit. Top to bottom: header (magnifying glass, or a semibold secondary `&` while the text matches no command, in a 16 pt column; plain "Filter or add a command" field with focus; trailing "N running"; 12 pt padding), optional inline banner, divider, rows (8 pt outer padding, 2 pt between rows), divider, footer ("Open Ampersand" leading, "Quit and stop N processes" trailing; 12 × 8 pt padding). Adding lives in the prompt, ⌘N, the empty state and the window's "+" menu, not in the footer. On open it selects the first row that needs attention (exited, gave up, couldn't start, port conflict), else the previous selection, else the first row.

**Row.** Glyph in a fixed 16 pt column, 8 pt gaps, name (middle-truncated), `:port`, spacer, trailing uptime, preceded by CPU or memory only when notable (`StatusText.notableMetrics`: CPU ≥ 50 %, memory ≥ 1 GB; 10 pt gaps), or stamp, then the always-laid-out hover start/stop button. Row padding 8 pt horizontal, 6 pt vertical. The expanded area is indented 32 pt so it aligns with the name.

**Window (System Settings reference).** `NavigationSplitView`, minimum 760 × 460 pt; sidebar 200 pt minimum, 240 pt ideal, `.sidebar` list style, `.searchable` in the sidebar, toolbar "+" menu. Detail: navigation title = command name, subtitle = stamp or state word; segmented Log / Settings picker in the principal toolbar slot; Start/Stop, Restart and a "⋯" More menu in the toolbar. Settings tab is a `.grouped` `Form` that applies as you edit (600 ms debounce, one Undo step per pause), titled sections: Command, (unnamed: Name, Group), Location, Environment, Network, Startup.

**The Fixed Columns Rule.** Nothing shifts when state, hover or numbers change: fixed glyph width, tabular digits, hover controls reserved in layout.

## Elevation & Depth

Depth is entirely the system's. The popover is the `MenuBarExtra` `.window` Liquid Glass material; the window uses standard sidebar and toolbar materials; window notices sit on the `.bar` material. There are no app-defined shadows, gradients, blurs or glass layers.

**The System Materials Only Rule.** If depth is needed, use a system material or a system container (`GroupBox`, `Form` section). Never hand-roll glass, blur or `.shadow`.

## Shapes

Continuous (squircle) corners, taken from the system wherever possible. Two app-set radii exist: the popover row selection (6 pt continuous) and the popover inline banner (8 pt continuous). Everything else (buttons, fields, form sections, group boxes, the popover itself) uses the control's native shape.

## Components

### Status Glyph (signature)
SF Symbols in a 16 pt column; `.contentTransition(.symbolEffect(.replace))` on change; hidden from VoiceOver (the row label says the state in words).

| State | Symbol | Colour | Trailing text |
|---|---|---|---|
| Running | `circle.fill` | `.green` | uptime (CPU, memory only when notable) |
| Starting, stopping, restarting | `circle.dashed` | `.orange` | backoff: `exit 1 · 14:02 · retry in 4s` |
| Exited, gave up, couldn't start | `xmark.octagon.fill` | `.red` | `exit 1 · 14:02`, `gave up after 5 restarts · exit 1`, `folder missing` |
| Stopped | `circle` | `.secondary` | `stopped` |
| Finished (exit 0) | `circle` | `.secondary` | `exit 0 · 14:02` |
| Running, health failing | `circle.fill` + small `exclamationmark.triangle.fill` badge, bottom trailing | `.green` + `.yellow` | metrics |

A clean exit is quiet: hollow glyph, stamp, no notification, no menu bar dot. Exit stamps persist until the user acts.

### Command Row (popover)
- **Default:** glyph, medium-weight name, secondary `:port`, secondary tabular uptime (plus notable metrics) or stamp.
- **⌘ held:** the glyph is replaced in place (opacity) by a secondary tabular `%1`…`%9` for the first nine visible rows, naming the ⌘1–9 shortcut; layout does not move.
- **Hover:** a borderless play/stop button appears at the trailing edge by opacity only (space always reserved).
- **Selected:** `NSColor.selectedContentBackgroundColor` fill (the accent; follows the user's accent setting), 6 pt continuous radius, `backgroundProminence(.increased)` so text uses the alternate selected (white) colour. The popover is the key window while open, and the HIG pairs that background with that text colour; `.selection` resolved to the non-key grey there, which left white text on light grey in light mode; expands in place to notices, a secondary `0.2% CPU · 7 MB memory` line while running, the last five non-blank log lines (secondary SF Mono, one line each, tail-truncated, selectable) or "No output yet.", and small actions: prominent Start / Stop / Start Again (Return), Restart (disabled while not active, kept visible as native), Show Log, Open in Browser (only with a port).
- **Context menu:** every action. **Tooltip:** name and command line. **VoiceOver:** one element, state in words, custom actions Start/Stop, Restart, Show Log.

### Prompt Row (popover)
Replaces the list when the filter text matches no command. Laid out as a selected, expanded row: a semibold secondary `&` in the glyph column, the command (minus recognised `cd …&&` and `KEY=value` prefixes) in SF Mono, middle-truncated, on the same selected-row fill. Below, indented 32 pt: a secondary summary ("No match. Adds “preview” on port 5173.") and small actions: prominent "Add and start" (Return) and "Edit first…" (⌥Return, opens the editor with the text). The spec comes from `CommandDraft`, so the editor's suggestions (name, port, health check, env, folder) apply unchanged.

### Group Header (popover)
Semibold secondary label; "Start All" / "Stop All" borderless small button on hover; context menu. Ungrouped commands sit under "No Group" whenever groups exist.

### Buttons
- **Primary:** `.borderedProminent`, accent fill, only for the expanded row's main action.
- **Secondary:** default bordered system buttons at `.controlSize(.small)` inside the popover.
- **Borderless:** footer controls (one `.primary` treatment for both), hover play/stop, dismiss `xmark`.
- **Footer Quit label** degrades "Quit and Stop 3 Processes" → "Quit and Stop 3" → "Quit" via `ViewThatFits`, with the full label as tooltip.

### Inline Banner (popover feedback)
Small controls; `info.circle` or `exclamationmark.triangle` in secondary; wrapping message; optional action (Retry, Show in Finder); borderless `xmark` dismiss; 10 pt padding on `.fill.tertiary`, 8 pt continuous radius. Sits above the list, never takes focus, auto-dismisses after 8 s.

### Window Notice Band
Banners and port conflicts in the window: one `GroupBox` per notice, `LabeledContent` with an SF Symbol `Label` message and fixed-size buttons (Retry / Show in Finder / Dismiss; Start Anyway / Kill pid N), stacked 8 pt apart, on `.bar` with a bottom divider, inset at the top of the detail pane only, never over the sidebar.

### Inputs / Fields
- **Popover filter:** plain text field, no autocorrect, no Writing Tools, no content-type suggestions.
- **Command field:** full-width, label hidden, left-aligned, SF Mono, 1 to 6 lines, prompt `npm run dev`. Code is not a right-aligned form value.
- **Grouped form rows:** label left, value right; "Choose…" / "Remove" beside paths; placeholders say the real default ("Not set", "None", "From the command").
- **Errors:** named in the section footer in secondary text with a recovery.

### Suggestion Chips (approved Impeccable choice)
Detected parts of a pasted command (cwd, env, port, name) shown under the command field in a flow layout: small `.bordered` buttons, label + secondary `xmark.circle.fill`; clicking removes the suggestion. Footer: "Detected from the command. Remove anything you don't want."

### Environment List
Native name/value rows in their own "Environment" section: SF Mono `NAME` field (max 200 pt) and value field, borderless `minus.circle` remove, "Add Variable" (`plus`) and "Import from .env File…". An invalid name gets a secondary `exclamationmark.triangle` with the rule as tooltip, and the footer explains that the row is held back until fixed. Otherwise the footer reads "Added on top of your login shell's environment." Empty: "No variables".

### Navigation (window)
Sidebar rows: `Label` with the status glyph as icon, middle-truncated name, trailing tabular `:port` via `LabeledContent`; section headers = group names (double-click or Rename… edits the name in place, with focus; clicking away keeps the typed name) and "No Group"; native `.onMove`; Delete key deletes. Toolbar "+" menu: New Command…, Add from Project Folder…, New Group…. New Group… (also in the Command menu and the command form) asks for the name in an alert first (Create disabled while blank), then scrolls the sidebar to the new group. Empty detail: `ContentUnavailableView` "No Command Selected".

### Log View
AppKit text view on `textBackgroundColor`, SF Mono at the system size, ANSI styles mapped per The Log Keeps Its Colours Rule, auto-follow with a "Jump to Latest" button when scrolled up, "No Output" `ContentUnavailableView` when empty. Clear / Copy / Export live in the toolbar ⋯ menu.

### Menu Bar Item
Template image of a semibold system `&` (20 × 18 pt): 45 % opacity when nothing runs, full when anything runs, plus a 5 pt dot when something crashed or gave up.

### App Icon
`Resources/Ampersand.icon`, Icon Composer (macOS 26 Liquid Glass): one glass layer, `&_` (an ampersand plus a cursor underscore) in Prompt Green, drawn from JetBrains Mono ExtraBold (SIL OFL 1.1, credited in `docs/design/icon.md`), on an automatic Graphite gradient; neutral shadow 0.5, translucency 0.4. SF Pro and SF Symbols are excluded from icons by Apple's licence.

### Motion
One token: the system `.snappy` spring for row expand/collapse, selection change and banner appearance; expanded content enters with opacity + move from top. Glyph changes use the symbol replace transition. Under Reduce Motion: a 0.2 s ease-in-out crossfade (opacity only), never a snap. No load-in choreography; motion only conveys state.

### Copy
- Quiet and exact. Sentence case everywhere: messages, buttons, menu items, field labels and picker options ("Show log", "Start again", "Quit and stop 2 processes"). Proper nouns keep their capitals (Ampersand, Finder, System Settings, URL, `.env`). This is a deliberate user decision (2026-10-13): Apple's writing guidance allows either style if applied consistently, although the macOS button HIG recommends title case.
- Labels name the action. Errors name the problem and the recovery ("Folder not found: ~/dev/x" + "Edit…").
- State words, lower case: stopped, starting, running, stopping, restarting, crashed, finished, couldn't start.
- Stamps join with " · ": `exit 1 · 14:02 · retry in 4s`, `signal 9 · 14:02`, `exit 0 · 14:02`, `gave up after 5 restarts · exit 1`.
- Metrics: CPU `0.3%` under 10 %, else whole percent; memory `7 MB` / `1.2 GB`; uptime `41s`, `5m`, `2h05`, `1d 3h`.
- Curly apostrophes and quotes; `…` for items that open a dialog.

## Do's and Don'ts

### Do:
- **Do** ask the user whenever a native macOS choice and an Impeccable choice differ.
- **Do** use system text styles, semantic system colours, system materials and stock controls; take System Settings as the window reference.
- **Do** carry status by glyph shape (filled, dashed, octagon, hollow) with system colour as confirmation.
- **Do** use `.monospacedDigit()` on every live number and reserve space for hover controls so nothing shifts.
- **Do** keep exit stamps until the user acts, and open the popover on the row that needs attention.
- **Do** use the `.snappy` spring for state changes and a 0.2 s crossfade under Reduce Motion.
- **Do** keep a control visible and disabled (Restart on a stopped command) rather than hiding it, as macOS does.
- **Do** put window notices in a `GroupBox` band on `.bar` in the detail pane.

### Don't:
- **Don't** put a hex colour, a fixed font size, a custom shadow, a gradient or hand-rolled glass in a view.
- **Don't** use SF Mono for anything that is not code, command or log data.
- **Don't** use the accent colour for status, or status colour outside the glyph.
- **Don't** use more than the `.body` text style in the popover.
- **Don't** add toggle-switch rows to the popover; it is a command bar, not a settings list.
- **Don't** use kickers or eyebrow labels, cards as structure, hero metrics, or sparklines/rings standing in for data.
- **Don't** confirm deletes with a dialog; offer Undo.
- **Don't** use SF Pro or SF Symbols in the app icon.
