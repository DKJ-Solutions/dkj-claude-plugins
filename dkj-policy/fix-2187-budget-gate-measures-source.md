## fix/2187-budget-gate-measures-source

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

Get-AlwaysOnMeasurement sums the RESOLVED copy of every document, so an edit to a persona body in this
tree is invisible to the ratchet until the clone catches up at a release. Substitute the tree
counterpart where one exists, name both figures, and pin it.

#### The reason, verified rather than taken from the report

`Get-AlwaysOnMeasurement` sums `$d.LfBytes` -- the copy that RESOLVED -- and never reads the
`TreeCounterpart` / `TreeBytes` fields the walk beside it already computes
(`always-on-budget-lib.ps1:289`, against `measure-context-lib.ps1:497` and `:522`). So in the one repo
where a marketplace clone mirrors this very tree, the ratchet judges the installed copy while the
branch edits the source. Confirmed on this checkout:
`plugins/dkj-subagents/dkj-subagents-alpha/personas/specialist-01-01-persona.md` is 30,899 B here
against 30,267 B in the clone.

#### One total, not two -- and this goes FURTHER than #2187 proposed

The report argues for a second measurement and for leaving the reported headroom on the clone figure,
because "a session genuinely does not pay for an unreleased edit". That half is declined, with a
reason. The headline figure is ALREADY not what a session literally pays: it is LF bytes, while the
session loads the on-disk CRLF copy, and the check says so in its own report
(`check-always-on-budget.ps1:171-177`). It is a repository-side, normalised figure. Preferring this
tree's copy of a document this tree owns is that same normalisation on a second axis, and it keeps ONE
number -- which the gate's own header requires, since the three carriers "cannot drift into describing
the same path differently". Two totals is exactly that drift, with a baseline field each.

The loaded figure is not lost: it is printed beside the judged one wherever they differ, the way the
CRLF figure already is.

#### The bound: only where the loaded copy RESOLVED

The substitution fires only for a document that exists at its resolved path AND has a counterpart in
this tree. Deliberately not for an unresolved one, and the difference is measurable today: both the
pre- and post-rename persona imports are live in `SPECIALISTS.md` during #2135's overlap, so
substituting on an unresolved target would count the renamed body at 30,899 B on top of the carried
30,267 B -- a 30k jump this branch did not cause, met by this very branch.

The cost of that bound, named rather than discovered later: a CI runner resolves no `~/` import at
all, so it CARRIES the recorded figure and does not re-derive the source size. The local gate is the
carrier that refuses, and `open-pr.ps1` runs it with `-Record` before every push, so the figure CI
carries is the judged one. Local and CI still describe the same subject.

### CREATE

- [x] `measure-context-lib.ps1`: `Get-AlwaysOnDocuments` carries `TreeLfBytes` beside `TreeBytes` --
      the ratchet compares LF, and the counterpart figure was on-disk bytes only
- [x] `always-on-budget-lib.ps1`: `Get-AlwaysOnMeasurement` judges the tree counterpart where one
      exists, reports the substitution as its own row set, and keeps `LoadedTotal` beside `Total`
- [x] `always-on-budget-lib.ps1`: `Get-AlwaysOnBudgetVerdict` passes the substituted set through to
      the reporting layer, as it already does for Carried and Dead
- [x] `check-always-on-budget.ps1`: print which copy was judged, both figures, and -- in the refusal --
      the repo path the author can actually edit
- [x] `build-shared-scripts.ps1`: regenerate the `dkj-policy` mirror of all three

### TEST

- [x] `always-on-budget.tests.ps1`: the substitution, its bound, and that local and CI still agree
- [x] the full gate: `check-plugin-integrity.ps1` + every suite, exactly as CI runs them
- [x] `check-always-on-budget.ps1` on this checkout: the total is unchanged today, since the resolving
      persona import has no counterpart during the rename overlap

### DEPLOY: fix/2187-budget-gate-measures-source

The always-on budget ratchet was measuring the wrong copy of the one document it most needed to watch.
A persona body, a manual or a lens that this repo ships is loaded through an absolute
`~/.claude/plugins/marketplaces/...` import, and the gate summed whatever sat at that path -- an
extracted copy that only advances at a release. So a branch could add 621 B to a persona body in this
tree and the gate answered `[OK] ... NOT growing`, because the figure it was summing had not moved.

**The weight was never cancelled, only deferred**, and that is the failure rather than the wrong
number: it lands on the always-on path at the next release, and the branch that then meets the refusal
is some later one that added nothing. A ratchet that refuses the wrong author is a ratchet that gets
`-Skip`'ped once and never obeyed again, which is the whole argument #2037 made for a ratchet over a
cliff.

The gate now judges this tree's copy wherever this tree has one, prints both figures where they
differ, and -- on a refusal -- names the repo-relative file the author can actually edit, instead of a
path under `~/.claude/plugins/` that the next plugin update overwrites.

**The substitution is bounded to a document whose installed copy RESOLVED**, which is not a detail:
during the persona rename the roster deliberately carries both the old and the new import, and
substituting on an unresolved one would have added a 30k body on top of the figure already carried for
its predecessor -- a jump no branch caused, met by whichever branch was open.

Nothing moves in this repo today: the total is still 110,075 B, because the persona import that
currently resolves is the pre-rename one, which has no counterpart left in the tree. The change is
visible the moment that settles.

**Score:** 3

#### What makes this deploy extra special

Every repo running `dkj-policy` gets this, but only one of them can notice it: the substitution needs a
marketplace clone that mirrors the checkout, which is true of a repo that consumes itself and of no
ordinary consumer. `Get-TreeCounterpart` already returned `$null` everywhere else, so for a consumer
this is a no-op by construction rather than by a flag.

What it buys them is indirect and worth naming anyway: the gate that guards their always-on budget is
maintained in a repo where that gate could not see its own always-on documents grow. Three of the four
documents on this repo's path are shipped to them.

**Score:** 1

#### Pull Request

The always-on budget gate judges the source copy of a plugin-carried document, not the marketplace clone

