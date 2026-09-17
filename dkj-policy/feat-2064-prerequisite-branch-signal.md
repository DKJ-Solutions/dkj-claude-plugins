## feat/2064-prerequisite-branch-signal

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

#### What #2064 measured

Picking up #2051, `claim-issue`'s parked-fix scan found `origin/fix/2048-closeout-repair-strategy`
and printed its ownership verdict: *NOT YOURS ... ASK THEM BEFORE YOU WRITE ANYTHING*. That verdict
asks one question -- is somebody mid-flight on the same work? -- and it was answered by reading: the
commit merely *mentioned* #2051 because it filed it, which the skill page itself calls "both ordinary
and correct".

**The actionable fact was a different one and nothing named it.** #2051's subject --
`scripts/maintenance/measure-closeouts.ps1` -- existed only on that branch. Every route to the issue
ran through that branch landing first. That is a dependency, not a collision, and no pickup check
looks for it:

- the **parked-fix scan** (#1853) reads a branch only as a competitor, and its own advice -- *do not
  settle this by reading the commit* -- points away from the read that would have shown it;
- **`triage-inbound`'s** *subject does not exist* check (#660) is about a name that names nothing; a
  subject sitting on an unmerged branch greps, opens and has history, so it reads as present to every
  check while blocking the work exactly as hard as absence;
- **`Get-TargetIssueWarnings`** resolves an issue to a pull request, and a parked branch has none by
  design.

#### The repair, and why it has two halves

The sixth pickup signal, measured over the branches the fourth and fifth scans have already surfaced
-- so it costs nothing where those two are silent, which is the ordinary run.

1. **Weight** -- `rev-list --count <trunk>..<branch>` per surfaced branch. Today 29 commits of
   unlanded work and a one-commit stray mention print as the same line.
2. **Overlap** -- the paths the issue's own body cites that are **absent from the trunk and present on
   that branch**. That is the decisive half: it turns *may be a prerequisite* into *is one*.

Trunk first, then the branches, and only for the paths the trunk lacks -- so the ordinary cost is one
`ls-tree` plus one `rev-list` per surfaced branch, and the per-branch read happens only when something
is genuinely missing from the trunk.

**Advisory, never a refusal** -- the bound the fourth and fifth signals already carry: a claim that
blocks costs the whole assignment (#1485). What it does change is the closing headline, exactly as
`$foreignParked` already does, because a run that names a prerequisite and then says *the work starts
here* has told the reader both things and settled neither.

### CREATE

- [x] `scripts/lib/claim-issue-lib.ps1`: `Get-IssuePathCitations` -- the path-shaped tokens an issue
      body cites, URLs stripped, deduped, capped
- [x] `scripts/lib/claim-issue-lib.ps1`: `Get-LsTreePaths` -- the parse of `git ls-tree`'s output
- [x] `scripts/lib/claim-issue-lib.ps1`: `Format-PrerequisiteReport` -- the block, with its three
      honest endings (no path cited / none missing / a prerequisite found)
- [x] `scripts/task/claim-issue.ps1`: collect the branches both scans surface, measure them, print the
      block, and let a find reach the closing headline
- [x] `scripts/task/claim-issue.ps1`: `body` added to the `gh issue view --json` fields
- [x] `scripts/sync/build-shared-scripts.ps1`: mirror both files into `plugins/dkj-policy/`
- [x] `plugins/dkj-policy/skills/claim-issue/SKILL.md`: the sixth signal documented beside the other five

### TEST

- [x] `scripts/tests/claim-issue.tests.ps1`: cases for the three new lib functions and for the
      script's structural properties
- [x] the full suite + `check-plugin-integrity.ps1` green
- [x] the block exercised by hand against this checkout (it needs a live tracker)

### DEPLOY: feat/2064-prerequisite-branch-signal

`claim-issue` now asks a sixth question at pickup, and it is the first one that is not about
ownership: **is a surfaced branch in my way rather than racing me?** Where the parked-fix or
title-overlap scan names a branch, the step weighs it -- how far ahead of the trunk it is -- and holds
the paths the issue's own text cites against the trunk. A path that is **absent from the trunk and
present on that branch** reaches its own verdict: *PREREQUISITE, NOT A COMPETITOR*, with the ordering
handed to the owner.

The five signals before it all answer *is somebody mid-flight on this work?*, which is why the
strongest ends in *ASK THEM BEFORE YOU WRITE ANYTHING*. Measured on the #2051 pickup (#2064): that
verdict fired on `origin/fix/2048-closeout-repair-strategy`, and reading settled it -- the commit
merely *mentioned* #2051 because it had filed it. What nothing named was that #2051's subject,
`scripts/maintenance/measure-closeouts.ps1`, existed only on that branch, so every route to the issue
ran through it landing first. No other check can see that: `triage-inbound`'s *subject does not exist*
is about a name that names nothing, while a subject on an unmerged branch greps, opens and has
history -- present to every check, and blocking the work exactly as hard as absence.

Three endings, deliberately not two. A prerequisite found; every cited path already on the trunk; or a
body citing no path at all, where the overlap question was never asked. Printing *not a dependency*
where nothing was tested is the failure this signal exists to remove, one layer in.

Advisory, like every signal in this family -- a claim that blocks costs the whole assignment (#1485).
What it does change is the closing line: where both verdicts fire the headline names **both**, because
they are different questions and naming one sends the reader to the block that settles the other.

Free on an ordinary claim: nothing surfaced, no git call made. Where something was surfaced the bill is
one `rev-list` per branch plus **one** `ls-tree` on the trunk carrying every cited path at once -- the
per-branch read runs only for the paths the trunk turned out to lack, which is normally none. Weights
are measured against `origin/<trunk>` where it exists, because a local trunk sitting behind origin
reports landed commits as unlanded and inflates a branch in the one direction this must not err.

Noticed the first time a pickup lands behind somebody else's branch, which is the day it saves the
whole detour.

**Score:** 3

#### What makes this deploy extra special

It is the first pickup signal that answers a question the others were not asking. The five before it
add evidence on one axis -- who else is working this -- and #2064's cost was a verdict that was
*correct on that axis* and pointed at the wrong question: the reader spent the time working out why
the branch mattered, from a block that had already told them to ask about ownership. Widening an
existing verdict would have made weaker evidence share a headline with stronger, which #2018 refused
by name one signal earlier; a second question gets its own block and its own hedges instead.

The issue body is read for the first time here, and it is read as **data**: bounded to path-shaped
tokens with a directory and an extension, URLs stripped first, nothing absolute, no `..`, no
option-shaped token, and none of it printed verbatim. Anybody who can open an issue writes that text,
and it now reaches a git argument list.

**Score:** 2

#### Pull Request

A surfaced branch is weighed, so a prerequisite is not read as a competitor

Plugins: dkj-policy
