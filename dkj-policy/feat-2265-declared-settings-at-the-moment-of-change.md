## feat/2265-declared-settings-at-the-moment-of-change

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

#### What #2265 reports, and what was verified before anything was written

A session waiting on `lint-en-tests` for PR #2262 offered enabling `allow_auto_merge` to stop waiting.
That setting is a declared decision -- `Get-ExpectedRepoSettings` in `scripts/repo-config.ps1` states it
`false` with its reason, and four documents in the tree say the same -- and the trunk was nine commits
ahead at that moment, which is that reason live. Both the setting and the armed auto-merge were reverted
in the same session.

Verified on this branch before writing: `check-repo-settings.ps1` reads **7 of 7 `[OK]`** in about a
second (so the revert is complete and the mechanism works), and nothing in the tree points a session at
that declaration before a setting is touched -- the check's own runner is a schedule (#1726), so its
earliest catch is after the change.

#### The shape chosen, of the three the issue lays out

Shapes 1 and 2 are built; shape 3 (a session-side guard) stays declined, because #1726 weighed it and
this branch is not a re-litigation of that decision. Shape 1 lands in the **portable manual** rather than
only in the lens: `CLAUDE.md` makes the shared source the default destination for a lesson learned here,
and a consumer's GitHub-side state drifts the same way (#1843 already made the check itself shared).

### CREATE

- [x] Portable hard rule in `plugins/dkj-subagents/dkj-subagents-alpha/manuals/specialist-05-15-manual.md`:
      read the declaration before proposing a GitHub-side setting change, with the measured instance
- [x] The measured instance and the local half in `.claude/specialists/lenses/specialist-05-15-lens.md`,
      under the repo-settings runner bullet
- [x] `scripts/release/ship-pr.ps1`: a line in the CI-wait invitation naming how many settings the repo
      declares, derived from `Get-ExpectedRepoSettings` and silent where a repo declares nothing
- [x] Mirror regenerated (`scripts/sync/build-shared-scripts.ps1`)
- [x] Corrected the stale `46 asserts` figure in the lens (actual 64 before this branch) -- an
      inconsistency in the sentence this branch was already editing, so fixed here rather than filed

### TEST

- [x] `scripts/tests/repo-settings-gate.tests.ps1` -- four asserts added for the pointer's shape: read
      through the guarded seam, names the check, silent on an empty declaration, and sitting inside the
      CI-wait invitation rather than in a docstring
- [x] The printed line smoke-tested against this repo's own declaration
- [x] Full lint + test gate via `open-pr.ps1`

### DEPLOY: feat/2265-declared-settings-at-the-moment-of-change

A GitHub-side setting -- a merge switch, a ruleset rule, a required check -- can be a decided answer with
a measured reason, and until now nothing pointed a session at that reason before it proposed changing
one. The declaration has been machine-readable since #1726, but its only runner is a daily schedule, so
its earliest catch is after the change and after whatever the change let through. Two pointers close that:
a hard rule in the system administrator's portable manual (read the declaration first, and an empty
declaration means nothing is watched rather than that a setting is free to move), and a line in
`ship-pr`'s CI-wait invitation -- the block that already answers *what do I do about this wait* now also
answers *not that*, naming how many settings the repo declares and the one command that prints them with
their reasons. The line is derived from `Get-ExpectedRepoSettings`, never asserted, so a repo that
declares nothing gets no line at all.

**Score:** 3

#### What makes this deploy extra special

Nothing to migrate and no behaviour changes: both halves are pointers, and the session-side guard that
#1726 weighed and declined stays declined. For a consumer of this workflow the manual travels with the
core team plugin and the `ship-pr` line travels with `dkj-policy`, where it stays silent until that repo
declares settings of its own -- the same rule that keeps `ship-pr`'s watch from naming a CI check it
cannot vouch for, applied to a repo's settings.

**Score:** 2

#### Pull Request

Point a session at the declared GitHub-side settings before it proposes changing one
