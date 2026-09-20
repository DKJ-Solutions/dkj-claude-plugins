## fix/2225-branch-name-resolves-gate

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

#### The reported reason, verified before anything was built

The report's explanation is an inference by somebody measuring from outside, so it was checked against
the tree before the repair was designed -- this repo's own rule, and the one that decides whether the
proposed repair is the right one at all. All four halves hold:

- `fix/2183-reserved-root-md-seam-row`'s document (`git show d0da0bb1:dkj-policy/fix-2183-...md`) names
  2183 in exactly two places, `## fix/2183-...` and `### DEPLOY: fix/2183-...`, and never as `#2183`.
- Its only real mention is `#2179`, which was closed at 10:49 that morning -- so the gate had no OPEN
  mentioned issue to block on and was correctly silent.
- PR #2211's body carries no closing keyword at all, so GitHub closed nothing at the merge and
  `verify-resolved-issues.ps1` had no keyword whose outcome to verify.
- #2183 stayed OPEN until 20:22 on September 20, when a session was asked by hand.

The one claim that does NOT hold as written is the parenthetical about `open-pr.ps1:515` "already
performing the same parse": `Get-BranchInfo` parses the branch's PREFIX, not its number. Nothing in this
tree read a branch name's issue number except `Get-BranchSlugWords` in `claim-issue-lib.ps1`, which
strips it to get at the slug's words. So the parse is new, and it is written to agree with that stripper
rather than to reuse a parse that was never there.

### CREATE

- [x] `Get-BranchNameIssue` in `scripts/lib/pr-issues-lib.ps1` -- pure, `'<prefix>/<n>-<slug>' -> <n>`,
      0 when the name declares none. Placed in the MIRRORED lib rather than in `branch-info.ps1`, which
      is repo-owned and does not travel to a consumer.
- [x] `open-pr.ps1`'s resolves gate folds that number into `$mentions`, beside what the document says.
      Into `$mentions` and never into `$resolveList`: the first makes the gate ASK, the second is the
      answer, and writing the branch's number there would close an issue nobody declared.
- [x] The refusal and the undeclared warning say WHERE the number came from, for a number the document
      does not carry -- otherwise the gate reports a "mention" the author greps for and cannot find.
- [~] Nothing added to `new-branch.ps1`'s already-done check. Dropped as out of scope: that check reads
      what `-Resolves` names at creation, and #2225's subject is the gate at the PR.
- [x] The branch name is deliberately NOT printed into the refusal. `open-pr.ps1` has never routed a ref
      through `Get-DisplayRef` and says so at its own foot, so a new raw ref print here would be a fresh
      site of #1623's class; the number is named on the line above and the author is standing on the branch.
- [x] `scripts/sync/build-shared-scripts.ps1` run -- both mirrors updated.

### TEST

- [x] 20 asserts for `Get-BranchNameIssue` in `scripts/tests/pr-issues.tests.ps1`, including the measured
      branch, the shapes that carry no number, and the stated false positive (`fix/5-minute-timeout` -> 5).
- [x] An AGREEMENT block against `Get-BranchSlugWords`: the two libs read this convention independently
      and neither loads the other, so what is pinned is that they cannot disagree about what a branch
      name's leading number is.
- [x] Six region-scoped source asserts that `open-pr.ps1` actually CALLS it and folds it into `$mentions`
      -- the half nothing else can see, since the function existing while the gate ignores it is
      indistinguishable from the defect.
- [x] Negative control run: replacing the call with `$branchIssue = 0` turns the suite red (2 failed),
      so the wiring asserts are not decorative.
- [x] Lint gate green (0 errors); all suites green.

### DEPLOY: fix/2225-branch-name-resolves-gate

A branch named after an issue now closes it. The resolves gate read the development document's prose and
an explicit `-Resolves`, and both are optional -- the prose is whatever the author typed, the flag is
memory. The branch NAME is where `new-branch.ps1` puts the number when a branch is cut for an issue, and
it was the one place nothing read, so a branch cut for an issue could merge closing nothing with no
backstop afterwards: `verify-resolved-issues.ps1` checks the outcome of a closing keyword, and there was
no keyword to check. `fix/2183-reserved-root-md-seam-row` did exactly that through PR #2211; the repair
landed, and #2183 stayed open until somebody asked by hand.

`Get-BranchNameIssue` reads `<prefix>/<n>-<slug>` and the gate folds that number in beside the
document's own mentions. The decision table is untouched, so the gate still refuses only when the issue
is OPEN and the PR declares neither `-Resolves` nor `-NoResolves` -- a branch that deliberately does not
close its issue still has `-NoResolves`, and the same escape valve now covers the branch named after an
issue it only partly addresses. The refusal names the branch name as the source, because an author sent
to grep a document that never mentioned the number is worse off than before.

**Score:** 4

#### What makes this deploy extra special

Every repo running this workflow gets the same gate, and on their branches too the question becomes
explicit: a branch named `fix/<n>-...` for an issue still open must now say `-Resolves` or `-NoResolves`
where it previously said nothing. That is one flag on the branches that were closing nothing by
accident, and it is the cost the repair was designed around rather than an unintended edge -- the
alternative is the silent open issue this gate exists to prevent. Nothing already declared changes, and
no PR gains a closing keyword nobody asked for: the branch's number joins the set the gate ASKS about,
never the set it answers with.

**Score:** 3

#### Pull Request

The resolves gate reads the branch name's issue number, not only the document's prose

