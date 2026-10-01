## feat/sessioncheck-remote-staleness

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
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Dave (October 1, 2026): *"I often don't notice at the start of a new session whether the plugins are out
of date, and I see no warning."* Two causes, both verified (#2673):

1. `connector-sessioncheck` compares the install against the **local** marketplace clone only, and stays
   silent about a stale clone by design (#1591). Measured the same day: "up to date" on 5.10.0 while
   GitHub had v5.11.0.
2. Even a correct verdict would have been invisible: a SessionStart hook's plain stdout goes to the
   model's context only (*"A successful hook's stdout is never shown in the transcript"*, hooks
   reference). Only `systemMessage` in JSON output reaches the user.

So: a new, separate hook `release-freshness-sessioncheck.ps1` that compares the running plugin version
(its own `plugin.json`) against the highest `vX.Y.Z` tag on the clone's `origin` (`git ls-remote`, which
writes nothing). It is silent unless behind and silent on every failure, bounded at 5 s, cached once per
session through `session-cache-lib`, and it answers in JSON with a `systemMessage` for the user and
`additionalContext` for the model. Tags rather than HEAD, because the trunk moves on every merge while an
update only delivers something at a release.

### CREATE

- [x] `plugins/dkj-policy/hooks/release-freshness-sessioncheck.ps1`, registered in `hooks.json`
- [x] A pointer in `connector-sessioncheck.ps1`'s docstring, where the stale clone is deliberately silent
- [x] Review (Victor, Sebastian, Edith): no findings

### TEST

- [x] `scripts/tests/release-freshness-sessioncheck.tests.ps1` (Tycho): behind, numeric comparison,
  current, ahead, tag shapes, no clone, unreachable origin, bad version, and the session-cache replay,
  against a local bare repository standing in for GitHub. 19/19
- [x] Live run against the real clone: behind prints the JSON (0.93 s including the PowerShell start),
  current is silent
- [ ] `open-pr` runs the lint gate and all suites before the push

### DEPLOY: feat/sessioncheck-remote-staleness

A new `dkj-policy` SessionStart hook, `release-freshness-sessioncheck`, warns the user visibly when
GitHub carries a newer release of the dkj plugins than the one the session is running. It names both
versions and the `update-plugins` skill. Until now nothing did: `connector-sessioncheck` compares against
the local marketplace clone, which only moves on `claude plugin marketplace update`, and every
session-start hook printed plain text that reaches the model but never the user. The new hook compares
release tags rather than commits, so work merged between releases does not trigger it. It is silent
when the session is current, offline or unable to check. The network probe runs once per session and is
bounded at five seconds.

**Score:** 3

#### What makes this deploy extra special

A consumer who falls behind a release now sees a warning in the terminal at session start, telling them
to run `/dkj-policy:update-plugins`. Before this they had to guess. A current session costs about one
`git ls-remote` per session start and shows nothing.

**Score:** 3

#### Pull Request

release-freshness-sessioncheck: warn the user at session start when a newer dkj release is out
