---
name: plugin-versions
description: >-
  Show, per enabled plugin, the version installed IN THIS CHECKOUT against the version the local
  marketplace clone holds, and a verdict on whether a plugin update is due -- so you can tell, on this
  machine, whether to run `claude plugin update` or `claude plugin marketplace update`. Read-only, no
  arguments, runs in any checkout on any machine. Use it when you are unsure whether this checkout is
  on the current plugin release, when a session behaves as if it loaded an older plugin, or before
  deciding to refresh the marketplace.
---

# plugin-versions -- installed here vs. the marketplace clone

This is the **plugin mirror** of `plugin-versions.ps1`: the same tested source as in the source repo,
shared here so consumers do not duplicate it -- the same argument as
[issue #81](https://github.com/DKJ-Solutions/claude-code-specialists/issues/81).

## What the skill does

Run the shared script from the **root of the consuming repo**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/task/plugin-versions.ps1"
```

**In the source repo, run its own copy instead -- `scripts/task/plugin-versions.ps1`.**
`${CLAUDE_PLUGIN_ROOT}` resolves into the plugin cache, which holds the last *released* mirror and so
lags its own source by however many merges have landed since. A consumer keeps no copy of their own, so
for them the line above is the correct one.

**Read-only.** It opens `~/.claude/plugins/installed_plugins.json` and the marketplace clone, shells to
`git` inside that clone to read HEAD, and prints. Nothing is written, nothing is pushed, nothing is
persisted -- the `syncedVersion` bookkeeping this repo removed on July 20, 2026 is deliberately **not**
brought back.

## The question it answers, and why nothing else does

"Is the plugin version this checkout loads the same as the one the marketplace clone holds, and if not,
which command closes the gap?" The connector session check is the nearest existing signal, and it goes
**inert** on a plain consumer with no sibling source checkout beside it. Two files, and it is worth
keeping them apart: the hook (`connector-sessioncheck.ps1`) prints
*"no verified workshop checkout found -- check skipped"* on its own early-exit path, so
`check-connectors.ps1` -- and with it the check 4 that compares versions -- is never invoked. That
string is the hook's own; grepping the check for it finds nothing. Either way you get no version
answer. This skill needs no source checkout: it reads what every consumer machine has.

Two facts make the reading trustworthy:

- **The install record is per checkout.** A record in `installed_plugins.json` is keyed on the plugin
  id **and** the `projectPath`, so this reports the version *this folder on this machine* actually
  loaded -- `version`, short `gitCommitSha`, and `scope` (`project` / `local` / `user`).
- **The marketplace clone advances only on `claude plugin marketplace update <marketplace>`** -- not on
  a push and not on a merge. So the clone's per-plugin `plugin.json` `version` is **cut-granular** and
  its git **HEAD sha** is the finer truth. Between two releases the `version` string cannot move, so it
  cannot show your install lagging the clone; the HEAD sha still can, and that is what the verdict
  compares. Whether the clone itself trails `origin` is a further gap this skill does not close -- it
  reads the clone as it stands.

## The output

A one-line summary, then one block per enabled plugin (every plugin is listed even under lockstep, so a
partial or split install state is visible):

```text
6 plugin(s): 4 up to date, 2 on the released version, with unreleased commits in the clone -- nothing to update (see below).
  clone 'dkj-claude-plugins': <path>  [HEAD 0711d4175d75, committed 2026-09-10T08:52:24Z, last fetch 2026-09-10T10:57:51]

dkj-subagents-alpha@dkj-claude-plugins
  installed here     4.33.0  0711d4175d75  project
  marketplace clone  4.33.0  HEAD 0711d4175d75
  verdict            up to date -- your install is at the clone's HEAD
                     -> the clone advances only on: claude plugin marketplace update dkj-claude-plugins

dkj-policy@dkj-claude-plugins
  installed here     4.33.0  810a0af28930  project
  marketplace clone  4.33.0  HEAD 0711d4175d75
  verdict            your install is on the released version 4.33.0 and the clone holds newer commits carrying that same version -- unreleased work, so there is no version gap for a plugin update to close
                     -> nothing to run -- 'claude plugin update' arbitrates on the version string and reports success without moving the install (measured, #1772); this closes at the next release cut
```

**That second block is the ordinary state of a checkout between two releases, and it is deliberately
not called *behind*.** The clone tracks the source's trunk; an install sits on the last release. So the
gap is unreleased work, and the reason no command is handed over is measured rather than cautious:
`claude plugin update` arbitrates on the **version string**, so across a same-version boundary it
reports *"already at the latest version"* and moves nothing
([#1772](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1772), September 10, 2026).
Until then this row was counted as behind and printed that command -- a report that looks acted on.

**Before pasting this output into a public issue, redact the paths.** The checkout root, the
install-administration path and the marketplace clone path are absolute, and on Windows they carry
your OS username -- replace each with a placeholder like the `<path>` above.

## The verdict, per plugin

| what it reads | verdict |
|---|---|
| install `gitCommitSha` **==** clone HEAD | **up to date.** The clone itself may still lag origin -- `claude plugin marketplace update <marketplace>` refreshes it if you expect newer. |
| install `gitCommitSha` is an **ancestor** of clone HEAD, and the two `version` strings **differ** | **the clone is AHEAD of your install** -> `claude plugin update <id> --scope project`. |
| install `gitCommitSha` is an **ancestor** of clone HEAD, and both sides carry the **same** `version` | **unreleased work in the clone**, and no command at all -- see the note under the output above. Counted in its own bucket, never as behind, and never an `[ERROR]` in `-Brief` (#1772). |
| install `gitCommitSha` is an **ancestor** of clone HEAD, but one side has **no** `version` | the same *clone is AHEAD* verdict and update command, with the line saying which side is missing and that the release boundary cannot be read from here. |
| install `gitCommitSha` exists but is **not** an ancestor of clone HEAD, or is unknown to the clone | **your install is ahead, or the clone is stale** -> `claude plugin marketplace update <marketplace>`. If the install `version` is also behind, it says so and names `claude plugin update` first. |
| **no `gitCommitSha`** on one side (an older record shape, or a non-git marketplace fetch) | the two `version` strings are compared instead, and the line says a sha was not available. |
| a whole side is **missing** -- no marketplace clone, no install record for this checkout, conflicting records | **cannot determine**, and the line says which side and the command that would fix it. |

## What it handles without failing

| state | what you see |
|---|---|
| no marketplace clone on this machine | every plugin: *"cannot determine -- no marketplace clone"*, with `claude plugin marketplace add`. |
| no `installed_plugins.json` at all | *"no install administration on this machine"*, verdict *cannot determine*. |
| enabled in settings but **no record for this checkout** (declarative enable only) | *"no install record in this checkout"* -> `claude plugin install <id> --scope project`. |
| only a path-less (machine-wide, `user`-scope) record | reported as such -- it is not read as this checkout's version. |
| several conflicting records for this checkout | all of them are shown, verdict *cannot determine*, with the repair install. |
| the checkout was moved or renamed | the `projectPath` no longer matches, so it reads as *not installed here* -- which is the true state after a move. |
| a non-git marketplace fetch (`.gcs-sha`, no `.git`) | the recorded sha is still read; ancestry is skipped and the verdict falls back to the `version` comparison. |
| no plugins enabled | one line saying so, exit 0. |

Non-Windows path separators are handled: every path is composed with `Join-Path` and the install-record
match normalises both sides.

## Parameters

The default view takes no arguments. `-Brief` is the one a caller might genuinely pass; the other two
are **test seams** a consumer never types.

| parameter | what it does |
|---|---|
| `-Brief` | emit one marker-prefixed line per plugin that has something to say, plus a `[SUMMARY]` tally, and nothing else -- no header, no per-plugin block, no colour. The shape a SessionStart hook can put in front of a session. |
| `-RootOverride` | the repo root to resolve the enable state and the install record against. |
| `-UserHomeOverride` | the home directory `~/.claude` hangs off -- points the enable state's user layer, the install record, and the marketplace clone at one fixture tree. |

### `-Brief`, and who reads it

This is what `connector-sessioncheck` prints on a machine with **no** sibling source checkout, which
is the ordinary state of a consumer rather than an edge case. The register checks there genuinely
cannot run -- `check-connectors.ps1` is source-only and is not plugin-carried -- so until
[#1591](https://github.com/DKJ-Solutions/claude-code-specialists/issues/1591) the hook printed
*"check skipped"* and a session got no version signal at all.

```text
[ERROR] dkj-subagents-ecomm@dkj-claude-plugins: the clone is AHEAD of your install (4.31.0 -> 4.32.0) -- claude plugin update dkj-subagents-ecomm@dkj-claude-plugins --scope project
[INFO] some-other@another-marketplace: cannot determine -- the clone's marketplace.json could not be read
[SUMMARY] 7 plugin(s) enabled here: 1 behind, 1 undetermined, 5 up to date.
```

`claude plugin update <id> --scope project` and `claude plugin marketplace update <marketplace>` both
appear in this mode and **they are not interchangeable**: the first moves *this checkout* onto what
the clone already holds, the second moves the *clone* onto what the remote holds. The `[ERROR]` lines
print the first, because that is the gap a reader closes here and now; the verdicts that print the
second are the ones this mode deliberately keeps out of `[ERROR]`. Running only the first against a
stale clone succeeds and reports a plausible version number, which is exactly why the refresh is
named beside it.

**The marker split is the contract, not cosmetics.** Only an install that is **behind** its clone is
an `[ERROR]`, because it is the only verdict a reader closes with a command here and now. A stale
**clone** is real and is deliberately *not* an error: it is the state of a cache this checkout does
not own, it costs nothing until the next update, and a session start that shouts about it trains the
reader to skim the marker that matters. Everything undetermined is `[INFO]` for the same reason --
*"cannot determine"* reports this machine's bookkeeping, not a defect in the plugin.

**Unreleased clone commits are `[INFO]` by that same rule, and they are the case it was written for
without knowing it** (#1772). There is no command to close that gap, so an `[ERROR]` there had nothing
for the reader to do -- and because it is the ordinary state between two releases, it was the loudest
marker this tool has, fired at every session start of every checkout, prescribing a no-op.

**A plugin that is up to date emits nothing**, and the `[SUMMARY]` line is what keeps that from being
ambiguous: it carries the count, so per-plugin silence reads as *up to date* rather than as *not
examined*. Under lockstep that is most of a normal run, which is the whole cost argument for the mode
existing.

## Requirements in the consumer

`git` (to read the marketplace clone's HEAD; a non-git fetch degrades gracefully). Nothing is
repo-owned -- there is no seam to scaffold. It resolves its repo root dual-context via
`${CLAUDE_PROJECT_DIR}`.

## Important

- **Read-only, and it persists nothing.** It reports a comparison; acting on it (`claude plugin update`
  / `claude plugin marketplace update`) stays a deliberate, separate step you run yourself.
- This script is maintained in the source repo; do not modify it locally in the consumer. A change
  lands first in the source (`scripts/task/plugin-versions.ps1`) and then travels via a release to the
  plugin mirror -- guarded by the shared-scripts drift lint.
