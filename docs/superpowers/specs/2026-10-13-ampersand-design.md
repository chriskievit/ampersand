# Ampersand: design spec

Date: 2026-10-13
Status: draft for review
Product record: [PRODUCT.md](../../../PRODUCT.md)

## 1. Summary

Ampersand is a native macOS menu bar app that keeps long-running terminal commands (port-forwards, `caffeinate`, `npm` dev servers) alive, visible, and one click away, so no terminal tab has to stay open just to keep a process running. It is fast, and strong on logs, restarts, notifications, and keyboard control.

**Success criteria**

- No terminal tab exists only to keep a process running.
- A glance at the menu bar shows whether anything has crashed.
- Opening the popover shows what runs, what died, and why; start/stop is one keystroke or click.
- Quitting Ampersand leaves no orphaned processes.
- Idle cost is negligible (target: < 0.1% CPU with popover closed, < 60 MB RSS with 10 commands).

## 2. Scope

**In v1**

- Commands with name, command line, working directory, environment, optional group, port, health check, auto-start, auto-restart.
- One level of optional groups; start/stop per command and per group.
- Popover-first UI (Command Bar direction) plus a secondary window for logs and settings.
- Live status, exit stamps, live logs with ANSI colour, CPU/memory/uptime, TCP/HTTP health checks.
- Auto-restart with backoff, crash notifications.
- In-app add/edit with command-line parsing; add from project folder (`package.json`).
- Launch at login; auto-start flagged commands on launch.
- Orphan cleanup after an Ampersand crash.
- Export / import of the config.

**Out of v1** (explicit non-goals)

- Port radar, Homebrew and Docker service types, coding-agent monitoring.
- Tags, nested groups, custom themes.
- Processes surviving Ampersand quitting (session-scoped by decision).
- Logs persisted to disk.
- Auto-restart on failed health check (recorded as a likely v1.1 option).
- Watching `config.json` for hand edits.
- Distribution, notarization, auto-update.

## 3. Platform and stack

- Swift 6.2 with strict concurrency, SwiftUI with AppKit where needed, macOS 26 only, Xcode 26.2.
- No third-party dependencies.
- Xcode project `Ampersand.xcodeproj` with one app target, plus a local Swift package `AmpersandCore` that contains all non-UI logic.
- App runs as an agent (`LSUIElement = YES`): no Dock icon while only the popover is in use; it activates as a regular app while the window is open.

## 4. UX brief (impeccable shape output)

**Job and audience.** One developer, mid-workday, glancing at the menu bar or opening the popover for a few seconds to check or toggle something. Visitor mode: Operate (scan state, act, leave).

**Selected direction: Command Bar.** Native macOS 26, driven like Spotlight with quick actions. Liquid Glass popover, SF Pro, SF Symbols, system colours. Chosen via the impeccable direction round (seed `f3019e17`, re-roll 1, steered to "native, aligns with modern macOS and Apple HIG"). Raises carried into the direction:

- Fixed status-glyph vocabulary: state is carried by shape, never colour alone.
- Exit stamps persist until the user acts ("nothing silently resets").
- One text style in the popover (the system `.body` style, 13 pt on macOS; never a hard-coded size); rank by weight and secondary label colour.
- Live numbers use tabular figures (`.monospacedDigit()`) and update in place with no layout shift.
- The system accent colour appears only on things you can press and on the current selection; status colour lives only in the glyph.

### 4.1 Menu bar item

- `MenuBarExtra` with a template image of an `&` glyph, so it follows the menu bar's appearance.
- Dimmed (secondary opacity) when nothing runs; full weight when anything runs.
- When any command is crashed or has given up, the icon switches to a template variant with a small dot. Template images cannot be coloured, so the signal is the shape, not red. This is the only attention-seeking state.
- Accessibility label reflects state ("Ampersand, 4 running, 1 crashed").

### 4.2 Popover

- `MenuBarExtra` `.window` style using the system's own popover material (Liquid Glass on macOS 26). No hand-rolled glass or blur layers.
- Opens with keyboard focus in a filter field. Typing filters by name and command line.
- Rows are listed under group section headers in config order; ungrouped commands follow under no header.
- Row content: status glyph, name, `:port`, CPU %, memory, uptime. Long names truncate in the middle; the full name and command line appear in the row's tooltip.
- Status glyph vocabulary (SF Symbols, system semantic colours; colour is secondary to shape):

  | State | Glyph | Colour |
  |---|---|---|
  | Running | filled circle | `.green` |
  | Starting / restarting / stopping | dashed circle | `.orange` |
  | Crashed / gave up / folder missing | octagon | `.red` |
  | Stopped | hollow circle | `.secondary` |
  | Running, health failing | filled circle + warning badge | `.green` + `.yellow` badge |

- Exit stamp replaces the metrics on exited rows: `exit 1 · 14:02 · retry in 4s`, `signal 9 · 14:02`, `gave up after 5 restarts`. A given-up row offers "Start again" and "Show log".
- Selection uses the system list selection highlight and the standard focus ring. Selecting a row (arrow keys or click) expands it in place: last ~5 log lines in SF Mono, plus action buttons.
- Keyboard:

  | Key | Action |
  |---|---|
  | ↑ / ↓ | Select row |
  | ↩ | Start / stop selected |
  | ⌥↩ | Start / stop selected row's group |
  | ⌘R | Restart selected |
  | ⌘L | Open full log in window |
  | ⌘O | Open `http://localhost:<port>` |
  | ⌘1 to ⌘9 | Select command by position |
  | ⌘N | Add command (opens the window with the editor) |
  | ⌘D | Duplicate selected |
  | ⌘, | Ampersand Settings |
  | Esc | Clear filter, then close popover |

- Mouse parity without relying on hover: the expanded row shows its action buttons permanently; collapsed rows show a start/stop button on hover; every row has a context menu (right-click) with every action: Start/Stop, Restart, Show Log, Open in Browser, Edit…, Duplicate, Move to Group ▸, Delete.
- Footer: `+ Add`, `Open Ampersand`, `Quit`. When processes run, Quit reads "Quit and Stop N Processes" (title case, per macOS menu and button convention).
- Group section headers carry a start-all / stop-all button and the same context menu at group level.
- In-popover feedback uses an inline banner at the top of the list (macOS has no toast pattern); it dismisses itself after the user acts or after 8 s, and never steals focus.

**Why add and edit open the window:** a `MenuBarExtra` popover closes when focus leaves it, which breaks file pickers, folder drag-and-drop, and multi-field forms. So `+ Add`, Edit…, and "Add from project folder…" open the main window and present the editor there. The popover stays a pure scan-and-act surface.

### 4.3 Window

- Opening the window switches the app to a regular activation policy (Dock icon, app menu); closing the last window returns it to agent mode.
- `NavigationSplitView`: sidebar with groups and commands (drag to reorder or move between groups, inline group rename, same context menu as the popover); detail with a segmented Log / Settings switch in the toolbar.
- **Log:** full scrollback (in-memory, ~10,000 lines per command), ANSI colour rendering, find (⌘F, the standard find bar), auto-follow to bottom with a "Jump to Latest" button when scrolled up, Clear, Copy All, Export….
- **Settings:** the same form as the editor sheet (section 6), in grouped `Form` style.
- **Menu bar commands (HIG: every action reachable from the menu bar):** a "Command" menu with Start/Stop, Restart, Start/Stop Group, Show Log, Open in Browser, Duplicate, Delete, each with the shortcut from 4.2; File menu with New Command (⌘N), Add from Project Folder… (⇧⌘N), Import… and Export…; standard Edit menu with Undo / Redo.

### 4.4 App Settings (⌘,)

A standard `Settings` scene, grouped form, three items: Launch at login, Notifications (on/off plus "Open System Settings" when denied), Default for "Restart on crash". Notification permission is requested in context, the first time a command with restart or notifications enabled is started, not at first launch.

### 4.5 States to design

- First run / no commands: popover explains in one line what Ampersand does and offers two buttons, "Add from Project Folder…" and "Add Command…".
- All row states in the glyph table, including "folder missing" and "port in use".
- Filter with no matches: "No commands match "xyz"" with a Clear button.
- Quit while processes run.
- Restored after an Ampersand crash: one inline banner "Cleaned up N processes from the last session."
- Config save failure: inline banner naming the problem, with Retry.
- Editor: env text with a parse error is marked on its line after the field loses focus; closing the editor with unsaved changes asks Save / Discard / Cancel.
- Deleting a running command stops it; Undo restores the command's configuration but does not restart it.

### 4.6 Visual and interaction rules

- SF Pro via system text styles everywhere; SF Mono only for real code and data (command lines, log lines, env text), never as a "technical" costume.
- Semantic system colours only (`.primary`, `.secondary`, `.separator`, accent, system status colours); no raw hex in views. Light and dark follow the system; Increase Contrast and Reduce Transparency respected and checked.
- System materials only; no decorative glass, gradients, or custom shadows.
- Motion only conveys state (row expand, status change). One timing token, the system `.snappy` spring (~200 ms); Reduce Motion swaps it for a crossfade. No load-in choreography.
- Visual feedback within 100 ms of any action (status flips to dashed "starting" or "stopping" immediately).
- VoiceOver: each row is one accessibility element whose label reads state in words ("web, running, port 3000, 3% CPU, up 41 minutes") and whose custom actions are Start/Stop, Restart, Show Log; group headers are headers.
- Every interactive control has default, hover, pressed, focused, and disabled states via system controls; disabled is visually distinct from stopped.
- Button and menu labels name their action ("Stop", "Restart", "Show Log"); errors name the problem and the recovery.
- Destructive actions (delete) use Undo rather than confirmation dialogs.
- No craft-floor refusals: no cards-as-structure, no hero metrics, no sparklines or progress rings standing in for data, no eyebrow labels.

## 5. Architecture

### 5.1 AmpersandCore (no UI)

| Unit | Responsibility | Depends on |
|---|---|---|
| `CommandSpec` | Value type: id, name, command, cwd, env text, env file, groupID, autoStart, port, health, restart. `Codable`, `Sendable`. | none |
| `Group` | Value type: id, name. | none |
| `ConfigStore` | Load and atomically save `config.json`; versioned schema; export / import. | `CommandSpec`, `Group` |
| `CommandLineParser` | Extracts suggestions (cwd from leading `cd X &&`, leading `KEY=value` env, port from known flags and `kubectl port-forward` mappings, name) from a pasted command line. Pure function. | none |
| `EnvParser` | Parses `.env`-style text (`KEY=value`, comments, quotes) into a dictionary; reports line-level errors. Pure function. | none |
| `ProcessRunner` | Spawns `$SHELL -l -c <command>` on a pseudo-terminal in a new session (own process group) with merged env and cwd; streams output bytes; reports exit status; `terminate()` = SIGTERM to group, SIGKILL after 5 s. | Darwin |
| `Supervisor` | `actor`, one per command. Owns the state machine and the restart policy; emits `SupervisorEvent`s. | `ProcessRunner`, `RestartPolicy`, `LogBuffer` |
| `RestartPolicy` | Pure backoff logic: 1, 2, 4, 8, 16, 32, 60 s cap; give up after 5 crashes in 2 min; reset after 60 s healthy uptime. Injectable clock. | none |
| `LogBuffer` | Ring buffer of lines per command (~10,000); splits on newlines and carriage returns; keeps ANSI codes raw. | none |
| `ANSIParser` | Converts SGR escape sequences to styled runs (16/256/truecolour, bold, dim, italic, underline); strips other escapes. Pure function. | none |
| `ResourceSampler` | Sums CPU % and resident memory across a process group (`proc_listpids` + `proc_pid_rusage`). Interval 2 s while UI visible, 10 s otherwise, paused while screen locked. | Darwin |
| `HealthChecker` | TCP connect to `localhost:port` or HTTP GET; 2xx, 3xx, 4xx count as healthy. Every 10 s; reports only. | Network |
| `PortProbe` | Before start, checks whether the port is bound and by which pid / process name. | Darwin |
| `ProjectDetector` | Reads `package.json` scripts in a folder and guesses ports (`--port`, `-p`, `PORT=`, Vite 5173, Next 3000). Returns suggested specs. | Foundation |
| `OrphanReaper` | Persists `{pgid, leaderPid, commandLine}` for running children to `pgids.json`; at launch kills groups whose leader still matches. | Darwin |

### 5.2 App target

- `AppModel` (`@Observable`, `@MainActor`): the single source of truth for UI. Holds specs, groups, and per-command live state (status, stamp, metrics, health, recent lines). Translates user intents into `Supervisor` calls; consumes event streams.
- `MenuBarExtra` with `.window` style: `CommandBarView`, `CommandRow`, `ExpandedRow`, `EmptyState`, `FilterField`.
- Window: `MainWindow` (`NavigationSplitView`), `LogView` (`NSTextView` wrapper for large scrollback with attributed ANSI runs), `CommandSettingsForm`.
- `CommandEditorSheet`: shared add / edit form (section 6), presented as a sheet on the main window (never from the popover), including the "Run once" test console.
- `ProjectImportSheet`: folder pick and script checklist.
- `NotificationService`: UserNotifications; tapping opens the command's log.
- `LoginItemService`: `SMAppService.mainApp`.
- `AppSettingsView`: the `Settings` scene (section 4.4).
- `AppCommands`: `CommandMenu("Command")` plus File menu items (section 4.3), sharing intents with the popover so shortcuts behave identically.
- `ActivationPolicyController`: switches between agent and regular activation policy as the window opens and closes.

### 5.3 Data flow

User intent → `AppModel` → `Supervisor` (actor) → `ProcessRunner`. State changes return as `AsyncStream<SupervisorEvent>` applied on the main actor. Log output is coalesced into ~50 ms batches before reaching the UI so a noisy server cannot flood the main thread.

### 5.4 Quit

`applicationShouldTerminate` returns `.terminateLater`; all supervisors stop in parallel (SIGTERM, SIGKILL at 5 s); then the app replies and exits. `pgids.json` is cleared on a clean exit.

## 6. Configuration (in-app first)

The UI is the primary way to configure. `config.json` is storage only and is not watched for hand edits.

### 6.1 Add / edit sheet (on the main window)

1. **Command**: large SF Mono field. Pasting or typing runs `CommandLineParser`; suggestions appear as removable chips under the field (accepted by default):
   - `cd ~/dev/web && npm run dev` → cwd `~/dev/web`, command `npm run dev`
   - `PORT=3001 npm start` → env `PORT=3001`, port 3001
   - `kubectl port-forward svc/api 8080:80 -n storefront` → name `api`, port 8080, TCP health
   - `vite --port 5173`, `next dev -p 3000` → port
   - `caffeinate -dimsu` → name `caffeinate`
2. **Name**: auto-filled, editable.
3. **Group**: menu of groups plus "New group…".
4. **More** (collapsed):
   - Working directory: path field, folder picker, drag-and-drop.
   - Environment: SF Mono `.env`-style text area with comments and highlighting; "Load from file…" links a `.env` file read at each start.
   - Port: number.
   - Health check: segmented None / Port / URL; URL field when URL.
   - Toggles: Start when Ampersand launches; Restart on crash (default on).
5. **Run once**: secondary button starts the command and streams its output inside the sheet before saving.

### 6.2 Add from project folder

Choose or drop a folder; `ProjectDetector` lists `package.json` scripts as a checklist with guessed ports; optionally create a group named after the folder. Each selected script becomes a pre-filled command, editable before saving.

### 6.3 Other editing

Duplicate (⌘D); reorder and move between groups by dragging in the window sidebar; inline group rename; delete with undo (⌘Z). Saving edits to a running command shows a non-blocking "Restart to apply"; Ampersand never restarts on its own because of an edit.

### 6.4 Storage

`~/Library/Application Support/Ampersand/config.json`, pretty-printed with stable key order:

```json
{
  "version": 1,
  "groups": [{ "id": "storefront", "name": "Storefront" }],
  "commands": [
    {
      "id": "5F1C…",
      "name": "web",
      "command": "npm run dev",
      "cwd": "~/dev/storefront-web",
      "env": "PORT=3000\n# local only\nNODE_ENV=development",
      "envFile": null,
      "group": "storefront",
      "autoStart": false,
      "port": 3000,
      "health": { "type": "http", "url": "http://localhost:3000/health" },
      "restart": true
    }
  ]
}
```

- `env` is stored as the raw `.env` text (comments preserved); parsed at start and merged over the login-shell environment. `envFile` values are merged after `env`.
- `~` in `cwd` is expanded at start.
- `health`: absent (none), `{ "type": "tcp" }` (uses `port`), or `{ "type": "http", "url": … }`.
- Command order within a group is array order.
- Export / Import… in the app menu writes or reads this file.

## 7. Process behaviour and error handling

**Start**

1. If `cwd` does not exist: status "folder missing" (octagon) with Edit…; nothing spawns.
2. If `port` is set and bound: expanded row shows `port 3000 in use by node (pid 4412)` with "Start anyway" and "Kill pid".
3. Spawn `$SHELL -l -c '<command>'` on a pseudo-terminal (200 columns, `TERM=xterm-256color`, `FORCE_COLOR=1`) in a new session.
4. Status "starting" until 1 s alive or the first passing health check, then "running". An exit within 1 s counts as a crash.

**Stop (user or quit)**: SIGTERM to the process group, status "stopping", SIGKILL after 5 s. Ends as "stopped"; no notification, no restart.

**Unexpected exit**

- Row shows exit stamp (`exit <code> · <time>` or `signal <n> · <time>`), kept until the user acts.
- With restart on: backoff 1, 2, 4, 8, 16, 32, 60 s cap, countdown in the stamp. After 5 crashes within 2 minutes: "gave up after 5 restarts" and a single notification. 60 s of uptime resets the backoff.
- With restart off: one notification per unexpected exit.
- Clicking a notification opens that command's log.

**Health**: shown separately from process status (warning badge plus tooltip such as "HTTP 502 for 30 s"). Never kills or restarts in v1.

**Sleep / wake**: no special case; dead port-forwards are handled by the crash and restart path. Sampling and health checks pause while the screen is locked.

**Ampersand crash**: on next launch `OrphanReaper` kills leftover groups whose leader pid still matches the recorded command line, then shows one inline banner in the popover.

**App errors**: spawn failures appear inline on the row with the error text; config save failures appear as an inline banner with Retry; in-memory state is never discarded.

## 8. Testing

- **Unit tests (AmpersandCore, Swift Testing)**: `CommandLineParser`, `EnvParser`, `ANSIParser`, `RestartPolicy` (with an injected clock), `ConfigStore` round-trip and versioning, `ProjectDetector` against fixture folders, `LogBuffer` line splitting and ring limits.
- **Integration tests (AmpersandCore, real processes)**: `ProcessRunner` and `Supervisor` against small scripts (`sleep`, `exit 3`, a script that ignores SIGTERM, a script that forks children) to verify group kill, SIGKILL escalation, crash detection, backoff and give-up, and that no child survives `terminate()`. `OrphanReaper` with a deliberately leaked group. `HealthChecker` against a local `NWListener`.
- **UI**: SwiftUI previews for every row state and the empty state, in light and dark mode. Manual verification checklist: keyboard map, VoiceOver labels, Reduce Motion, Increase Contrast. An XCUITest smoke test: add a command, start it, see "running", stop it.
- **Performance check**: Instruments with 10 commands including one noisy `npm` server; confirm the idle targets in section 1 and no main-thread hitches while logs stream.

## 9. Design process gates (required in the implementation plan)

Design artifacts produced so far: `PRODUCT.md` (impeccable init), this spec's section 4 (impeccable shape brief, reviewed against impeccable's Apple-platform, craft-floor and Operate references and the ui-ux-pro-max app checklist), and the direction contract in `.impeccable/surfaces/ampersand-views-commandbarview-swift.md` (seed `f3019e17`).

Before UI code is written:

- Read the direction contract and impeccable's `craft-floor.md`. Build to the contract; do not dilute it.
- The contract target path `Ampersand/Views/CommandBarView.swift` must exist in the project layout (or the brief is re-pointed with `impeccable surface-brief write`).

After the UI is built, these steps are part of "done", in this order:

1. **Screenshots**: run the real app and capture the popover (each row state, empty state, filter-empty), the window (Log and Settings) and the editor, in light and dark mode, and with Increase Contrast. Use `screencapture`, never a browser.
2. **`/impeccable audit`** (native variant, `audit.native.md`), scored against Apple HIG for macOS. Fix every P0/P1.
3. **ui-ux-pro-max pre-delivery checklist** (accessibility, interaction, light/dark, layout), adapted for macOS: pointer-and-keyboard instead of 44 pt touch targets.
4. **`/impeccable critique`** of the popover against the direction contract; fix in one batch, confirm with at most one more round.
5. **`/impeccable polish`** final pass.
6. **Finish review and DESIGN.md**: impeccable's finish reviewer audits the build against the contract, then the documenter writes `DESIGN.md` from the shipped app. The FINISH line in the contract is not discharged until both exist.

Impeccable has no macOS platform; `PRODUCT.md` records `macos` and its iOS (Apple HIG) reference is applied with macOS substitutions (pointer and keyboard instead of touch targets, menu bar commands, no Dynamic Type requirement beyond system text styles).

## 10. Open decisions (later iterations)

- Auto-restart on sustained health failure (likely v1.1, per-command opt-in).
- Final visual details of the `.env` editor versus a key/value table (user agreed to iterate later).
- Which features to add after v1: port radar is the most likely candidate.
