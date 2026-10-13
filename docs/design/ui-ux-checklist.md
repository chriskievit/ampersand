# Ampersand: ui-ux-pro-max Pre-Delivery Checklist (Task 23 Step 3)

Date: 2026-10-13. Source: `ui-ux-pro-max` 2.5.0 SKILL.md, "Pre-Delivery Checklist" and "Quick Reference" priorities 1 to 9.
Adapted for macOS 26: pointer and keyboard replace 44 pt touch targets; safe-area, notch, bottom-nav and tablet rules are n.a.; "dynamic text" means system text styles (macOS has no Dynamic Type).

Evidence: `docs/design/screenshots/*.png` (retina 2x; `window-log-*` were taken with the window not key), source in `Sources/AmpersandApp/**`, spec section 4.
Contrast numbers come from pixel sampling of the screenshots (darkest glyph pixel against the adjacent background, WCAG formula). They are approximate because of anti-aliasing and Liquid Glass translucency.

## Checklist

### Visual Quality
- pass: No emojis as icons. SF Symbols only; the `➜` in logs is program output.
- pass: Consistent icon family. SF Symbols throughout; custom `&` template image only in the menu bar (`MenuBarIcon.swift`).
- n.a.: Official brand assets. No third-party brands shown.
- fail: Pressed/hover states do not shift layout. The hover start/stop button is inserted into the row HStack (`CommandRow.swift:29-38`), so the CPU/memory/uptime columns jump left by about 24 pt on hover. Spec 4 requires "no layout shift".
- pass: Semantic tokens. Only `.primary/.secondary/.tertiary`, `.separator`, `.fill`, system status colours; no hex in views.

### Interaction
- pass: Clear pressed feedback. System `Button` styles everywhere; rows give selection feedback within one frame.
- pass: Target size (pointer-adapted). Small-control buttons are about 22 pt high with 8 pt gaps; every hover-only control has a context-menu and keyboard equivalent.
- pass: Motion timing. One `.snappy` spring (~200 ms); Reduce Motion swaps it out (`CommandBarView.swift:28-29`, `CommandRow.swift:42`).
- pass: Disabled states. Restart greyed when stopped (popover-port-conflict.png), Revert/Save greyed when clean (window-settings.png).
- pass: VoiceOver order and labels. Rows are single elements with state in words and custom actions; group headers have `.isHeader`.
- pass: No conflicting gestures. Sidebar drag-to-reorder, single-click select and double-click rename are separate targets.

### Light/Dark Mode
- fail: Primary text >= 4.5:1. Sidebar command names measure 1.85:1 (light, not key), 2.74:1 (dark, not key) and 3.06:1 (dark, key window, window-settings.png) against 10.5:1 for form labels in the same window. They render like secondary text in both appearances.
- pass: Secondary text >= 3:1. Popover metrics and "stopped" (`.tertiary`) measure 3.15:1 dark and 3.9:1 light; health message 6.0:1 light. Borderline but compliant.
- pass: Dividers and interaction states visible in both modes. Divider lines and grouped-form separators are visible in both popover shots.
- n.a.: Modal scrim. Sheets use the system sheet presentation, no custom scrim.
- pass: Both themes tested. Popover and log window in light and dark; Settings tab and editor sheet only in dark (acceptable, same system form).

### Layout
- n.a.: Safe areas for headers/tab bars/CTA bars. Desktop windows and popover.
- pass: Scroll content not hidden behind fixed bars. Popover scroll view is sized to its rows; sidebar footer uses `safeAreaInset`.
- fail: Verified at the sizes it ships in. In the fixed 360 pt popover the footer truncates to "Quit and Stop 2 Proces…" in every popover screenshot; with 10+ processes it gets worse.
- n.a.: Gutters by device/orientation. Popover is fixed width; window has a min size of 760 x 460.
- pass: 4/8 spacing rhythm. Paddings are 8/12/16 with 2/6 pt micro gaps inside rows; consistent between popover and window.
- pass: Long-form measure. The only long text is log output, which is code and should run full width.

### Accessibility
- pass: Icons have labels. Status glyph is hidden and its state is spoken in the row label; toolbar and hover buttons have titles or `accessibilityLabel`.
- fail: Form fields have labels, hints and clear errors. The Name field's placeholder reads "Command" when the Command field is empty (fallback at `CommandDraft.swift:122` used as prompt at `CommandForm.swift:47`). Also the Command field is right-aligned (see Fixes), which makes a code value hard to read and edit.
- pass: Colour is not the only indicator. Status is shape-first (filled, dashed, octagon, hollow, badge).
- fail: Reduced motion and text size without layout breakage. Reduce Motion is honoured and only system text styles are used, but the popover footer already breaks at the default size (truncated Quit label).
- pass: Traits and states. Popover rows add `.isSelected`; sidebar uses `List` selection; More uses a system `DisclosureGroup`.

### Quick Reference spot checks (priorities 1 to 9, items not covered above)
- fail: `focus-states` / `nav-state-active` (P1, P9). Popover selection uses a custom `.selection.opacity(0.22)` fill (`CommandRow.swift:49`). It renders as a neutral grey, not the accent colour, and has no focus ring. Spec 4.2 asks for the system selection highlight and the standard focus ring, and spec 4 reserves the accent colour for the current selection. In popover-light.png the selected row is only faintly separated from the glass.
- pass: `keyboard-nav` / `keyboard-shortcuts` (P1). Full spec 4.2 key map in `CommandBarView.swift:150-183`; Esc clears then closes.
- pass: `escape-routes` / `modal-escape` (P1, P9). Editor sheet has Cancel; group rename handles Esc.
- pass: `truncation-strategy` (P6). Names truncate in the middle with a tooltip; log tail lines truncate at the tail with "Show Log" as the full view.
- pass: `number-tabular` (P6). `.monospacedDigit()` on all live numbers.
- pass: `system-controls` / `platform-adaptive` (P4). `NavigationSplitView`, grouped `Form`, segmented toolbar picker, system popover material.
- pass: `empty-states` (P8). First-run view, "No commands match" with Clear, "No Command Selected" with a hint.
- pass: `undo-support` / `destructive-emphasis` (P8). Delete uses Undo; "Delete Group" is `role: .destructive`.
- pass: `input-helper-text` (P8). Environment has persistent helper text and per-line errors.

## Fixes (ordered by impact)

1. Sidebar command names read as secondary text (contrast 1.85:1 to 3.06:1).
   `Sources/AmpersandApp/Window/Sidebar.swift:60`. Set the style explicitly:
   ```swift
   Text(runtime.spec.name)
       .foregroundStyle(.primary)
       .lineLimit(1)
       .truncationMode(.middle)
   ```
   Root cause is not confirmed from source alone (nothing sets a style on this `Text`). The prime suspect is the per-row `.draggable` / `.dropDestination` at `Sidebar.swift:17-20`, which can make `List` rows render with a drag-preview style. If `.primary` does not fix it, move reordering to `ForEach(...).onMove` plus `.dropDestination` on the `ForEach` and remove the per-row modifiers. Verify in both appearances with the window key.

2. Popover footer truncates "Quit and Stop N Processes".
   `Sources/AmpersandApp/Views/CommandBarView.swift:124-136`. Keep the spec copy and give it room:
   ```swift
   Menu { … } label: { Label("Add", systemImage: "plus") }
       .labelStyle(.iconOnly)
       .help("Add Command")
       .menuStyle(.borderlessButton)
       .fixedSize()
   Spacer(minLength: 8)
   Button("Open Ampersand") { model.openMainWindow() }
       .buttonStyle(.borderless)
       .lineLimit(1)
   Button(quitTitle) { NSApp.terminate(nil) }
       .buttonStyle(.borderless)
       .fixedSize()
       .layoutPriority(1)
   ```
   If "Open Ampersand" then truncates at 10+ processes, rename it "Open Window" or show it as `macwindow` icon-only with a help tag.

3. Popover selection is a custom grey tint with no focus ring.
   `Sources/AmpersandApp/Views/CommandRow.swift:47-51`. `.selection` follows window key state and resolves to grey in the menu bar panel. Use the accent explicitly and add a ring so selection reads in both appearances:
   ```swift
   .background {
       if isSelected {
           RoundedRectangle(cornerRadius: 8, style: .continuous)
               .fill(Color.accentColor.opacity(0.18))
               .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 1)
       }
   }
   ```
   Alternative closer to spec 4.2: `Color(nsColor: .selectedContentBackgroundColor)` with white text on the collapsed header line only, but that clashes with the buttons in the expanded part, so prefer the tinted fill plus ring.

4. Command field is right-aligned (trailing value column of the grouped `Form`).
   `Sources/AmpersandApp/Window/CommandForm.swift:24-26`. Put the label above and the code full width, leading:
   ```swift
   VStack(alignment: .leading, spacing: 4) {
       Text("Command")
       TextField("Command", text: $draft.commandText, prompt: Text(verbatim: "npm run dev"), axis: .vertical)
           .labelsHidden()
           .multilineTextAlignment(.leading)
           .font(.system(.body, design: .monospaced))
           .lineLimit(1...4)
           .textFieldStyle(.roundedBorder)
   }
   ```
   The rounded border also fixes the second problem visible in window-settings.png: Command and Port look like read-only text. Apply `.textFieldStyle(.roundedBorder)` to Port at `CommandForm.swift:70-71` too.

5. Name placeholder shows "Command" when nothing is typed.
   `Sources/AmpersandApp/Window/CommandForm.swift:47`. Only preview the derived name once there is a command:
   ```swift
   TextField("Name", text: $draft.name,
             prompt: draft.commandText.trimmingCharacters(in: .whitespaces).isEmpty
                 ? Text("Taken from the command")
                 : Text(draft.makeSpec().name))
   ```
   Keep the `"Command"` fallback in `Sources/AmpersandCore/Config/CommandDraft.swift:122` for the saved spec; it is only wrong as a placeholder.

6. Hover start/stop button shifts the metrics column.
   `Sources/AmpersandApp/Views/CommandRow.swift:29-38`. Always reserve the slot and fade it:
   ```swift
   Button { model.toggle(runtime.id) } label: {
       Image(systemName: runtime.status.isActive ? "stop.fill" : "play.fill")
   }
   .buttonStyle(.borderless)
   .help(runtime.status.isActive ? "Stop" : "Start")
   .accessibilityLabel(runtime.status.isActive ? "Stop" : "Start")
   .opacity(hovering && !isSelected ? 1 : 0)
   .allowsHitTesting(hovering && !isSelected)
   .accessibilityHidden(!(hovering && !isSelected))
   ```
   (The row's custom accessibility actions already cover Start/Stop for VoiceOver.)
