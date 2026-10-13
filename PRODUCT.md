# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

<!-- Impeccable's schema knows web/ios/android/adaptive only. This is a native macOS app; apply Apple HIG (macOS) and borrow Apple-native guidance from the iOS reference where it transfers. -->

## Stack

Swift 6.2 + SwiftUI (AppKit where SwiftUI falls short), macOS 26 only, built with Xcode 26.2. Chosen by the user.

## Users

One user: the author, a backend/platform developer. During a workday they keep several long-running commands alive: `kubectl port-forward`s to cluster services, `caffeinate` to stop the Mac sleeping, and a few `npm` dev servers. Today each one occupies a terminal tab that must stay open and that they must remember not to close.

## Product Purpose

Ampersand is the `&` you put after a command, made visible. It keeps the commands you would otherwise leave running in a terminal tab alive, visible, and one click away, and it stays out of your way.

Success: no terminal tab exists only to keep a process running. At a glance the user knows what runs, what died, and why, and can start or stop anything in one click.

## Positioning

A personal tool, not a product for sale. Native and fast: SwiftUI instead of a web view, and strong on live logs, auto-restart with backoff, crash notifications and keyboard control. Out of scope for v1: port radar, Homebrew/Docker service types, coding-agent monitoring.

It differs from a terminal multiplexer by being a resident, glanceable control surface. It differs from a system service manager by being session-scoped: everything belongs to the app and stops when the app quits.

## Operating Context

- Popover-first: daily use (status, CPU/memory, start/stop) happens in the menu bar popover. A full window opens for adding/editing commands and reading full logs.
- Commands run through the user's login shell (zsh) so PATH, nvm, kubectl contexts, and aliases behave as they do in Terminal.
- Typical load: 3 to 10 commands, several running at the same time for hours.
- Port-forwards drop when pods restart or the network changes; restarting them is a frequent manual chore today.

## Capabilities and Constraints

- Commands, optionally in groups (one level, no tags). Each command has: name, command line, working directory, environment variables, and a "start when Ampersand launches" flag.
- Start, stop, and restart per command and per group.
- Project auto-detect: pick a folder; Ampersand reads its project config (e.g. package.json scripts) and pre-fills name, command, working directory, and port.
- Process model (decided): Ampersand supervises children directly, each via the login shell in its own process group on a pseudo-terminal; stop is SIGTERM then SIGKILL to the group; config is a hand-editable JSON file in Application Support; leftover process groups from a crash are cleaned up on next launch.
- Lifecycle: quitting Ampersand stops every process it started. No orphaned processes.
- Monitoring: running/stopped/crashed status, live stdout/stderr log per command, auto-restart on unexpected exit (with backoff), macOS notification on unexpected exit, and health/resource info (uptime, CPU/memory, optional port or URL check).
- Ampersand can launch at login.
- Single user, local only. No sync, no accounts, no distribution beyond the author's own Mac.

## Brand Commitments

- Name: **Ampersand**. The `&` glyph is the identity.
- Voice: quiet and exact. It "stays out of your way".

## Evidence on Hand

None yet. Real example commands come from the user's current terminal tabs (port-forwards, `caffeinate`, `npm run dev`-style servers).

## Product Principles

1. Out of the way until needed: a glance at the menu bar is enough when all is well.
2. Failure is loud, success is quiet: a crashed command is the one thing that may ask for attention.
3. Behaves like the terminal: same shell, same environment, same output; no surprises versus running it by hand.
4. Session-scoped and tidy: Ampersand owns what it starts, and cleans it all up on quit.
