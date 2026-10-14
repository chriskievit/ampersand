# Contributing to Ampersand

Ampersand is a single-maintainer personal tool that other people are welcome to
use, fork and improve. Contributions are welcome. The expectations below are
here so you don't waste effort, not to gatekeep.

## Before you start

**Open an issue before a large PR.** Ampersand has a deliberately small
surface: commands, one level of groups, a menu bar popover and one window.
That is a design constraint, not an accident, so a well-built feature can still
be declined for being outside it. A short issue first saves you from building
something that gets turned down.

Small, obvious fixes (a bug, a typo, a broken link) can go straight to a PR.

## Running locally

You need macOS 26 and Xcode 26 (Swift 6.2). There are no third-party
dependencies.

```bash
scripts/run.sh            # debug build, then launch it
scripts/run.sh release    # same, release configuration
scripts/install.sh        # release build into /Applications
```

`scripts/bundle.sh` turns the SwiftPM executable into `build/Ampersand.app`:
it copies `Resources/Info.plist`, compiles the Icon Composer document in
`Resources/Ampersand.icon` with `actool`, and signs the bundle ad hoc.

Ampersand reads and writes `~/Library/Application Support/Ampersand/`. A
development build uses the same folder as an installed one, and `scripts/run.sh`
quits the installed copy first. To keep your own commands running, give the
development build a folder of its own:

```bash
AMPERSAND_CONFIG_DIR=~/ampersand-dev scripts/run.sh
```

It then runs as a second copy next to the installed app, with its own commands,
and leaves the login item alone. Settings (`UserDefaults`) are still shared.

## Testing

**A PR is expected to arrive tested.** The project is split in two:

- **`AmpersandCore`** holds everything that can be tested without a UI:
  parsing, configuration, process spawning and supervision, restart policy,
  monitoring and orphan cleanup. Cover new or changed behaviour here with
  [Swift Testing](https://developer.apple.com/documentation/testing) tests in
  `Tests/AmpersandCoreTests`, following the patterns that are already there.
  Please don't introduce another framework.
- **`AmpersandApp`** is the SwiftUI and AppKit layer and has no test target.
  Keep logic out of views: if something can be decided without a view, it
  belongs in `AmpersandCore` with a test. For UI changes, describe what you
  checked by hand in the PR, in light and dark mode.

If you're changing code whose tests are missing, add them as part of the PR
rather than leaving the gap where you found it.

Process tests spawn real shells and processes. They must clean up after
themselves and must not depend on each other's leftovers. A test that only
passes sometimes counts as failing.

```bash
swift test
```

## README screenshots

The images in `docs/screenshots/` are taken with the fictional configuration
in `docs/screenshots/fixture-config.json`: a "Storefront" group with `api`,
`web`, `worker` and `storybook`, plus a few ungrouped commands. The commands
print plausible output or run harmless local tools, so no real hostname,
namespace, path or token can leak through a log line. Never capture your own
commands.

To retake them, export your own configuration first, then:

```bash
cp docs/screenshots/fixture-config.json ~/Library/Application\ Support/Ampersand/config.json
scripts/run.sh release
```

Capture single windows (`screencapture -o -l <window id>`) in light and dark
mode, keep the names in `docs/screenshots/`, and keep the shown states ones
the app can actually reach.

## What CI enforces

CI runs on every pull request on a macOS 26 runner and mirrors these commands
exactly. Run them locally first. It's faster than waiting for a red build:

```bash
swift build
swift test
scripts/bundle.sh release
```

Swift 6 language mode with strict concurrency is on. Warnings about sending
non-`Sendable` values are real bugs here, not noise.

## Project invariants

These aren't style preferences. A PR that breaks one won't be merged.

**Session-scoped, no orphans.** Everything Ampersand starts stops when it
quits. Each command is the leader of its own process group, and stopping it
signals the whole group (`SIGTERM`, then `SIGKILL` after a grace period). The
orphan reaper must only ever kill groups it can prove it started, which is why
it matches on process start time and not on the process ID alone.

**Behaves like the terminal.** Commands run through the user's login shell on
a pseudo-terminal. Don't sanitise, rewrite or second-guess the command line or
its environment.

**Native first.** Use standard SwiftUI and AppKit controls, system colours and
system fonts. Labels, buttons and menus use sentence case. When a custom
design and the platform disagree, the platform wins. `DESIGN.md` records the
rest.

**Failure is loud, success is quiet.** Only something that needs the user may
ask for attention: a crash, a failed health check, a port conflict. A command
that exits with status 0 is finished, not crashed.

**Responsive under load.** Output is read off the main thread, batched before
it reaches the UI, and back-pressured when a command floods. A change that
makes the UI scale with output volume will be asked out again.

## Commits

This repo uses [Conventional Commits](https://www.conventionalcommits.org/)
with the Angular preset, and releases are fully automated by semantic-release
on merge to `main`. Your commit type decides the version bump:

| Prefix | Effect |
| --- | --- |
| `feat:` | minor release |
| `fix:`, `perf:` | patch release |
| `BREAKING CHANGE:` in the body | major release |
| `docs:`, `chore:`, `ci:`, `refactor:`, `test:`, `style:` | no release |

**Don't hand-edit `CHANGELOG.md` or the version fields in
`Resources/Info.plist`.** semantic-release owns them and will overwrite your
changes.

## Pull requests

- One focused change per PR. Unrelated refactoring makes review harder and
  usually gets asked out again.
- Say what you changed and why. If there's a tradeoff, name it. That's more
  useful than a clean-looking diff.
- For UI changes, include before and after screenshots, using the fictional
  configuration described above.
- Link the issue it addresses, if there is one.
- Expect review comments. This is a personal tool with opinions baked in;
  questions about an approach aren't a rejection of it.

## Working with AI agents

Agents are welcome here. Ampersand is largely built with them, so it would be
odd to ask contributors not to use them. There's no disclosure requirement.

**But the person who opens the PR owns the diff.** That means:

- You understand every line you're submitting and can explain why it's there.
- You can answer review questions about it without going back to re-derive the
  reasoning.
- You ran `swift test` locally and it passed, and you launched the app and
  tried the change.
- The tests are real tests, not assertions shaped to match whatever the code
  currently does.

A PR that reads as unreviewed agent output (tests that don't test anything,
invented APIs, changes to files the task never needed to touch, a description
that doesn't match the diff) will be closed rather than reviewed line by line.
Review time is the scarce resource on a single-maintainer project, and that's
the whole reason for the rule.

## Code of conduct

Participation is covered by the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE) that covers this project.
