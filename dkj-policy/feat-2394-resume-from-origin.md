## feat/2394-resume-from-origin

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

#2394: a branch on origin should be finishable from another machine. Two gaps in #2387's `-TakeOver`:
it refused an issue with no claim marker (the common case -- 9 of 9 measured), and "the same account"
was exactly one login, while one person works under several.

#### Scope

- `-TakeOver` resumes an untagged issue with exactly one branch on origin, on the branch's AUTHORS:
  every commit off the trunk must carry one of this checkout's names.
- `DKJ_OWN_ACCOUNTS` (user-level env var, deliberately not `repo-config.ps1`) declares the other
  accounts one person works under; `-TakeOver` and the parked-fix scan's NOT YOURS read it.
- The NOT YOURS block names the route past it.
- NOT here: `-Candidates` showing such an issue as resumable -- that is #2392's subject.

### CREATE

- [x] `claim-issue-lib.ps1`: `Get-OwnAccountNames`; `Get-TakeOverVerdict` gains the untagged path
  (`take-untagged` / `foreign-author` / `unknown-author` / `ambiguous-branch`) and `-OwnAccounts`;
  `Format-HandoverComment` names the authors when there was no old tag; NOT YOURS names the route.
- [x] `claim-issue.ps1`: reads `DKJ_OWN_ACCOUNTS`, fetches the one untagged branch and reads its
  authors off origin's trunk, handles the three new codes.
- [x] Plugin mirror regenerated (`build-shared-scripts.ps1`).
- [x] `claim-issue` and `sweep-issues` skill pages describe the untagged case and the declaration.

### TEST

- [x] `claim-issue.tests.ps1`: 473 passed -- new asserts for every new verdict code, the declared
  account on both paths, a second undeclared holder, the env parsing and the untagged handover comment.
- [x] `native-capture.tests.ps1`: the bounded-site count moved 78 -> 79 for the one new fetch, audited.
- [x] Live dry runs on this repo: #2304 (branch by `DaveKJohn`) refuses as `foreign-author`, and
  resumes with `DKJ_OWN_ACCOUNTS=DaveKJohn`; #2375 (branch by `davekokbwj`) resumes with no declaration.

### DEPLOY: feat/2394-resume-from-origin

`claim-issue.ps1 <n> -Tag -TakeOver` now also resumes an issue that carries **no claim marker**, which is
the common case: a session that never ran `-Tag` leaves only its branch on origin. There exactly one branch
for the issue must be on origin, and every commit on it off the trunk must be authored under one of this
checkout's names; one foreign author, or an author list that could not be read, refuses. A new user-level
variable, `DKJ_OWN_ACCOUNTS`, declares the other accounts one person works under, and both `-TakeOver` and
the parked-fix scan's `NOT YOURS` verdict count them as yours. That block now also names that route.
Showing such an issue as resumable in `-Candidates` stays with #2392.

**Score:** 3

#### What makes this deploy extra special

N/A -- this changes how a session picks up its own parked work, which no subscriber of a service sees.

**Score:** N/A

#### Pull Request

claim-issue -TakeOver: resume an untagged branch on origin, and count a person's declared other accounts as theirs
