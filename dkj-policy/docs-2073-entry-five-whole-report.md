## docs/2073-entry-five-whole-report

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

#### What this branch answers

`new-branch/SKILL.md` carries the inventory of the six consoles this workflow prints somebody else's
words to, and entry 5 is `claim-issue`'s own report. That entry was written when the report had one
scan. It has three now -- the parked-fix scan (#1853/#1858), the title-overlap scan (#2018) and the
prerequisite scan (#2064) -- and entry 5 still names only the first. The count in front of the list is
right; the entry under it is two signals behind, in the one document whose stated job is to stay
accurate about exactly this ("the list is the thing that has to be kept true, not the number").

- [x] Read the entry against `scripts/task/claim-issue.ps1` and `scripts/lib/claim-issue-lib.ps1`
      rather than against #2073's summary of it, and count the value classes the report actually
      prints
- [x] Check what #2069 has landed: PR #2076 is open and green, so the fifth signal's own
      `Format-ForConsole` call is in flight -- the entry must therefore read true both before and
      after it merges

### CREATE

- [x] Entry 5 rewritten to name **four** classes of value, not one: the issue TITLE; the AUTHOR,
      SUBJECT and BRANCH NAMES the parked-fix scan prints per commit; the BRANCH NAMES the
      title-overlap scan prints off a `git branch -a` capture the per-commit strip never reaches
      (#2018/#2069); and the BRANCH NAMES plus cited FILE PATHS the prerequisite scan prints (#2064)
- [x] The "no push access" point kept and widened -- the cited paths are read out of an issue BODY,
      so they have the same author as the title, one field over
- [x] One paragraph added after the list's own lessons: an entry goes stale the same way the list
      does, one level in, and a new signal/field/caller inside a listed site is an edit to that entry

### TEST

- [x] Every claim in the new entry read back off the two scripts: the title at
      `claim-issue.ps1:231`, the parked-fix fields at `:390`/`:392`/`:393`, the title-overlap branch
      names at `:430` (no strip today -- #2069's subject), the prerequisite branch and paths at
      `:514`/`:516`
- [x] The wording deliberately carries no temporal claim about #2069: it says the fifth signal *needs*
      a second call at the caller, which is true whether or not PR #2076 has merged when this lands
- [x] Lint gate + all suites green (`check-plugin-integrity.ps1` and `scripts/tests/*`, via open-pr)

#### Wider than the report asked for, deliberately

- [x] #2073 asked only for the title-overlap scan. The same read found the prerequisite scan (#2064,
      merged as PR #2071) missing from the entry too, and its cited file paths come out of an issue
      body -- a lower-privilege author than any branch name. Naming one and not the other would have
      re-created the exact defect being repaired

### DEPLOY: docs/2073-entry-five-whole-report

Entry 5 of `new-branch/SKILL.md`'s six-site injection-surface inventory now names every value
`claim-issue`'s report prints, instead of the one scan that existed when the entry was written: the
issue title off the tracker, the parked-fix scan's author/subject/branch names, the title-overlap
scan's branch names off the `git branch -a` capture the per-commit strip never reaches (#2018, and why
#2069 needs a second call at the caller), and the prerequisite scan's branch names plus the file paths
it reads out of an issue body (#2064). The list's closing lessons gain the one this repaired: an entry
goes stale the same way the list does, one level in, so a new signal, field or caller inside a site
already listed is an edit to that entry.

**Score:** 2

#### What makes this deploy extra special

This is the document a consumer audits their own console against -- the page that says which of their
printed lines carry somebody else's characters and what guards each one. An entry that under-describes
its own site is worse than a missing entry, because it reads as having been checked: a reader taking
entry 5 at face value was told the title-overlap scan's branch names were already accounted for by
text that had never mentioned them. The list's own discipline covered the case one level up and not
this one; it does now.

**Score:** 2

#### Pull Request

Entry 5 of the six-site list names every value claim-issue's report prints, not two
