## feat/1886-shopify-theme-archive

> **How this file is read.** A step is `- [ ]` until it is resolved -- `- [x]` done, or
> `- [~]` dropped with the reason, which exists so nobody ticks a box for work they did not do.
> open-pr and ship-pr both refuse while one is still open, and there is no `-Force`.
>
> **FOUR `###` HEADINGS, AND NEVER A FIFTH** -- PLAN, CREATE, TEST, DEPLOY are the whole top
> level. A section needing its own heading goes in as a `####` UNDER whichever of the four owns
> it. No gate in YOUR repo reads a heading, so this half is on you -- only the repo that authors
> this workflow refuses a fifth (Dave, August 26, 2026).
>
> **AND NOTHING BRANCH-SPECIFIC ABOVE THE FIRST OF THOSE FOUR HEADINGS** -- everything between the
> title and it is this guidance, which is identical in every branch document. A status line, a note about
> THIS branch or an instruction to a session belongs under one of the four, normally as a `####`
> in PLAN. THIS half open-pr refuses, in every repo, before the push -- it reads the shape, so a
> guidance block in your own language passes and your own paragraph here does not (Dave,
> August 26, 2026; refused since #1650).
>
> **DEPLOY takes no steps of its own, and it is WRITTEN LAST** -- it is what the branch DID, once
> TEST says so. Written while steps above it are still open it states an INTENTION, and no gate
> holds it against what landed: the step gate splits this file at that heading and counts only
> above it. The PR title is the one exception -- new-branch -Title writes it at creation, because
> open-pr composes the PR title from it. It is the one part of this file that travels verbatim
> into `CHANGELOG.md` at the merge. In each tier, write the reason
> ABOVE the Score line -- anything below it is discarded.
>
> Relative links in that text resolve FROM THIS DIRECTORY -- `CHANGELOG.md` sits here too, so
> write each path exactly as it reads in this file.
>
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Converge candidate 4 of #1886: the two BWJ stores each carry their own theme-archive script, aliased on Get-ThemeListJson. The Shopify-shaped half moves into dkj-subagents-shopify, which already owns every other theme mechanism.

#### The ownership verdict, and why it is not dkj-policy-bwj

The #1881 ruling sends anything the two BWJ stores share to `dkj-policy-bwj` unless it is obviously
universal. This bullet is the one where the ruling's *axis* is the wrong axis: archiving a theme is
not a BWJ practice, it is a Shopify one. `dkj-subagents-shopify` already owns every other theme
mechanism -- `push-preview`, `sync-main`, `preview-theme`, `sync-rules`, `shopify-cli-lib`, and the
live-theme guard the refusal below is shaped by -- so the precedent is set by the plugin's SUBJECT
rather than by its reader count. `push-preview` and `sync-main` ship there today with exactly the
same two readers.

#### What the two stores actually carry

- `smartwatchbanden:scripts/theme/archive-and-remove-theme.ps1` -- 183 lines, Dutch, one theme per
  run, an inline `$ProtectedIds` table, an external-theme gate, and **it removes the theme**: with
  `-Execute` it calls the Shopify CLI's destructive theme command itself.
- `xoxowildhearts:scripts/theme/archive-theme.ps1` -- 407 lines, English, many themes per run, backed
  by a 964-line pure rules lib and a 1094-line suite, with committed manifest receipts, and it never
  removes anything: it prints the command for the caller to run as its own visible act.

#### For smartwatchbanden this is a repair, the same shape candidate 1 turned out to be

The archive-only shape is not a preference. `dkj-subagents-shopify`'s live-theme guard is a PreToolUse
hook that reads the COMMAND STRING of a tool call, so a destructive theme command buried inside a
`.ps1` is invisible to it -- the call reads `powershell -File ... -Execute` and there is nothing to
match. smartwatchbanden enables that plugin, so its removal-capable script is a live wrapper vector in
that store today. Converging closes it.

#### The bound: verify-archive.ps1 is NOT in scope

`xoxowildhearts:scripts/theme/verify-archive.ps1` is an `ONLY-IN` finding, and this issue's own bar
says a mechanism only one store has is not a convergence candidate. It stays in that consumer. Its
three rules travel anyway, because they live in the same pure lib and stranding them would break it;
that consumer then dot-sources the shipped lib instead of its own copy. Its two seams
(`Get-ThemeArchiveDurableRoot`, `Get-ThemeArchiveDurableLabel`) stay that consumer's.

### CREATE

- [x] `scripts/lib/theme-archive-rules.ps1` -- the converged pure lib, source of truth here
- [x] `scripts/task/archive-theme.ps1` -- the converged task script, archive-only, dual-context
- [x] Two registry entries in `scripts/lib/shared-scripts-lib.ps1`, both `Plugin = 'dkj-subagents-shopify'`
- [x] `plugins/dkj-subagents/dkj-subagents-shopify/skills/archive-theme/SKILL.md` -- every script lives in a skill
- [x] Mirror into the plugin with `scripts/sync/build-shared-scripts.ps1`
- [x] `plugins/dkj-subagents/dkj-subagents-shopify/README.md` -- state what the plugin now owns

### TEST

- [x] `scripts/tests/theme-archive-rules.tests.ps1` -- 153 asserts, green -- the pure lib, driven by both stores' real names
- [x] Lint gate green -- 0 errors (`scripts/lint/check-plugin-integrity.ps1`)
- [x] Full suite green -- 101 suites, 159s

### DEPLOY: feat/1886-shopify-theme-archive

`dkj-subagents-shopify` now owns the theme archive: `scripts/task/archive-theme.ps1`, the pure
`scripts/lib/theme-archive-rules.ps1` behind it, and an `archive-theme` skill. Candidate 4 of #1886,
and the third of the four to land.

**The ownership question this bullet was filed with had two candidate answers and the right one was
neither.** #1886 weighed `dkj-policy-bwj` against `dkj-subagents-shopify` under the #1881 ruling --
*what the two BWJ stores share goes to `dkj-policy-bwj` unless it is obviously universal*. The
ruling's exception asks for a demonstrated reader outside the two stores, and this bullet does not
need that test, because the ruling's axis is the wrong axis for it: archiving a theme is not a BWJ
practice, it is a Shopify one. The plugin that owns the live theme already owns `push-preview`,
`sync-main`, `preview-theme`, `sync-rules`, `shopify-cli-lib` and the live-theme guard -- and two of
those ship with exactly the same two readers. The precedent is the plugin's *subject*, not its reader
count.

**For `smartwatchbanden` this is a guard repair, not a relocation** -- the same shape candidate 1
turned out to have. That store's copy removes a theme from inside a `.ps1` with `-Execute`, and this
plugin's live-theme guard is a `PreToolUse` hook that reads the *command string* of a tool call: a
destructive theme command buried in a script is invisible to it, because the call reads
`powershell -File ... -Execute`. That store enables the plugin, so the bypass is live there today. The
converged script never removes anything; it prints the command, with the marker where the seam is
answered, for somebody to run as its own visible act.

**One behaviour is new, and it is the place NEITHER copy was right.** `smartwatchbanden` refused to
archive a third party's theme without `-AllowExternal`; `xoxowildhearts` dropped that gate with a
sound reason -- it never removes anything, so a read-only local backup harms nobody and the gate had
no subject. Both are right about the archive and both miss the *printed command*, which for a store
with third-party themes is the exact line that breaks a live integration, handed over without a word
under a heading saying the archive makes the removal recoverable. So the archive is never gated, the
command is never suppressed, and `Get-ExternalThemeWarning` tells the caller whose theme it is at the
moment they are about to paste it. The prefixes are a seam, unanswered by default.

**Two real defects in the inherited code, both found by writing the first assert against them**, not
by reading:

- `Get-ThemeArchiveVerdict -Id ''` was rejected by the **parameter binder**, so its own
  `'no theme id given'` refusal was unreachable -- a guardrail that reads as one and is dead code.
  Worse in the caller's direction: a binder failure under the script's `Stop` is terminating, so it
  would have killed a whole multi-theme run where the verdict it stood in for skips one theme.
- `Get-ThemeArchiveContentDigest -Records $null` returned a **real-looking SHA-256 for an archive with
  no files** -- the same unroll at a parameter boundary that `Merge-ThemeArchiveEvent`'s own banner
  documents, one function over and unguarded. That is precisely the "fingerprint of something" its
  *empty in, empty out* contract exists to forbid, on the path that reaches it with nothing.
  `Format-ThemeArchiveManifest` carried it too, where it would have written a phantom file line into a
  **committed** receipt and counted it in `files:`.

The `ALIASED` finding itself dissolves rather than being renamed: `Get-ThemeListJson`, the one function
the sibling check could match on, is gone -- both calls go through the plugin's own
`Invoke-ShopifyCli`.

153 asserts in `scripts/tests/theme-archive-rules.tests.ps1`, including the round trip that renders a
receipt, reads it back and re-merges -- the shape no unit assert can see, and the one that caught the
phantom event.

Candidate 4 of [#1886](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1886), which stays
open: candidate 2 (`lint-brain.ps1`, a translation plus a merge) and candidate 3 (`plugin-scripts.ps1`,
whose question is now *what kind of artefact* rather than *which plugin*) are each still their own
pickup.

**Score:** 3

#### What makes this deploy extra special

A Shopify consumer gets the step that makes removing a spent preview theme *recoverable* -- and gets it
as a mechanism with a suite rather than as something to write again. A Shopify store has a hard ceiling
of 20 themes, so spent previews have to leave, and both existing consumers had independently built this
by hand under two different filenames with neither able to find the other.

What they actually receive differs by store, which is the point of converging rather than moving:
`smartwatchbanden` gains multi-theme runs, committed receipts and the closing of a live guard bypass;
`xoxowildhearts` can delete roughly 1,400 lines of local script and lib and dot-source the shipped one
instead. A third-party store gains the warning neither copy had.

Scored 3 rather than higher because nothing changes for them on the upgrade alone: the plugin ships the
mechanism, and the repair lands when they adopt it. Scored 3 rather than `N/A` because the thing shipped
is a script they run, not an internal rearrangement -- and because one of the two subscribers is running
a guard bypass until they do.

**Score:** 3

#### Pull Request

dkj-subagents-shopify owns the theme-archive rules

