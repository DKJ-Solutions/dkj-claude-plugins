## fix/3049-update-plugins-conflicting-scopes

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

Repair #3049: where this checkout's own install records disagree on scope, `update-plugins` updates
each distinct scope rather than falling back to one `--scope project` call.

### CREATE

- [x] `update-plugins.ps1` (and its `dkj-policy` mirror): one update per distinct canonical scope
  recorded for this checkout, never `managed`; the disagreement named above step 1; the extra records
  counted in the summary
- [x] `update-plugins` skill page: the fallback paragraph corrected, the #3049 paragraph added

### TEST

- [x] `update-plugins.tests.ps1` scenarios 21 (project + local + user shadow; local + managed),
  22 (-DryRun) and 23 (a user sibling and a user shadow are one call, from code review): 128 pass, 0 fail

### DEPLOY: fix/3049-update-plugins-conflicting-scopes

`update-plugins` now updates every install record a checkout holds for a plugin, at each scope those
records name ([#3049](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3049)). Where a
checkout's records disagreed on scope (a `project` and a `local` record side by side, a state a
session start can produce), the run fell back to one `--scope project` call and left the other record
behind, under `0 failed`, while its own receipt said `CONFLICTING`. A path-less `user` record beside
them was skipped as well. Now each scope gets its own `claude plugin update`, `managed` excepted, and the
disagreement is named before step 1.

**Score:** 2

#### What makes this deploy extra special

`update-plugins` no longer leaves a second copy of a plugin behind in a checkout that holds two install
records for it, so a session there stops loading the older version after a run that reported success.

**Score:** 2

#### Pull Request

update-plugins updates every disagreeing checkout record, one call per scope

