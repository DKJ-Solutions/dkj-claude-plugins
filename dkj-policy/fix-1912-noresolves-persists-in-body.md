## fix/1912-noresolves-persists-in-body

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

Record a -NoResolves decision in the PR body so a second open-pr run on the same branch recognises it,
the way it already recognises a published Closes line.

#### The asymmetry, verified against the tree before anything was written

`open-pr.ps1` folds the body of an already open PR into the body the gate judges, and its own comment
says why: a resumed branch must not be blocked for failing to repeat a decision GitHub already holds.
That reasoning is about a decision PUBLISHED ON THE PR, and it is exactly as true of "closes nothing".
But recognition was keyed on a closing keyword, and `-NoResolves` writes none -- so one of the two
answers the gate itself calls honest was durable and the other evaporated when the process ended.

### CREATE

- [x] Verify the report against the tree: `Get-ResolvesDecision` reads the body only through
      `Get-ClosedIssueNumbers`, and `-NoResolves` writes nothing into it. Symptom and reason both stand.
- [x] `scripts/lib/pr-issues-lib.ps1`: `Get-NoResolvesMarker`, `Test-NoResolvesMarker`,
      `Add-NoResolvesMarker`, `Remove-NoResolvesMarker` -- the marker owned by one function rather than
      spelled out at five call sites.
- [x] `Get-ResolvesDecision`: a verdict for a body that carries the marker, and `DeclaredNone` on every
      verdict so the caller reads a boolean rather than a missing property. Closing keywords are still
      read FIRST, because they are what GitHub acts on at the merge.
- [x] `scripts/release/open-pr.ps1`: `$resolvesDeclaredNone` carries the answer to both body writers --
      the fresh-PR path and the existing-PR path -- and a `-Resolves` run strips a marker that has
      stopped being true.
- [x] The marker is re-appended AFTER a `-RefreshBody`, for the reason #919 gives for the closing block:
      a refresh of a body whose description is its leading section rewrites everything below it.
- [x] Mirror to the plugin copy (`build-shared-scripts.ps1`).
- [x] The two shipped skill pages say the flag is needed once per branch, not once per command.

### TEST

- [x] `pr-issues.tests.ps1`: the marker's recognition (whitespace, case), its invisibility inside a code
      span and a fence, idempotence in both directions, and the add/remove cycle not accumulating
      whitespace at the foot of a body.
- [x] The run that used to be refused: an open mention, no flag, and a body carrying what the first run
      wrote -> allowed, closes nothing, nags about nothing.
- [x] `DeclaredNone` asserted on all seven verdicts, so the caller's condition cannot silently invert.
- [x] The whole suite green.

### DEPLOY: fix/1912-noresolves-persists-in-body

`open-pr.ps1 -NoResolves` now WRITES ITS ANSWER DOWN, as `<!-- resolves: none -->` in the PR body, and
the resolves gate reads it back the same way it already reads a published `Closes #<n>` -- closes #1912.
The gate folds an open PR's body into what it judges precisely so a resumed branch is not asked to repeat
a decision GitHub already holds; that recognition was keyed on a closing keyword, which `-NoResolves` by
definition never writes, so of the two answers the gate's own refusal text calls honest, one was durable
and the other lasted only as long as the process. Measured on
`feat/1843-portable-repo-settings-runner`: `open-pr -NoResolves` opened PR #1909, and `ship-pr` -- whose
step 1 re-runs `open-pr` -- refused the same branch minutes later for a question that had been answered.

A later `-Resolves` on the same branch strips the marker rather than leaving a body that both closes an
issue and states it closes none, and the marker is re-appended after a `-RefreshBody` for the reason
#919 gives for the closing block one step up. Recognition ignores code spans and fences, because a
document explaining the marker necessarily writes the marker and this entry does.

For this repo's maintainers it removes a refusal that cost seconds and taught the wrong reflex: the
obvious way past it is to pass the flag again, which is how a session learns to pass `-Resolves`
reflexively -- the exact failure this gate exists to prevent. It lands hardest where it matters most, on
a PR delivering one step of a multi-step issue, which is the shape #1843 had and which has already been
closed by accident once.
**Score:** 3

#### What makes this deploy extra special

A subscriber running this workflow meets it as one fewer refusal in the two-command flow the skill pages
prescribe -- `open-pr`, then `ship-pr` -- which is the flow a consumer follows most. Nothing to migrate
and nothing to undo: a branch whose PR predates this simply gets the marker on its next run. They notice
it the first time they ship a PR that closes nothing, and are told on the page rather than by a gate.
**Score:** 2

#### Pull Request

The -NoResolves decision persists in the PR body

