## fix/2173-lint-gate-progress-record

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

Issue #2173 as filed proposes publishing a `lint-gate` record from inside `check-plugin-integrity.ps1`,
on the reading that the check "knows its own check count as it walks" and so "has both a current and a
total". Read against the script that is not so: `Write-Coverage` prints a per-class `checked <n>` and no
total number of checks exists at runtime, so a bar would need a literal or a self-parse of the script's own
headers threaded through ~48 call sites, over checks so uneven that a fraction of them would sit still for
most of the 78 seconds. The parent, `Invoke-WorkflowGates`, already holds the stopwatch and blocks in one
child call -- the shape `ship-pr`'s CI wait publishes -- so it publishes a label and a start, and no bar.

#### Not covered, deliberately

`cut-release.ps1` runs its own lint call (`& powershell ... | Out-Host`), outside `Invoke-WorkflowGates`,
and stays silent on the statusline. A cut is asked for and attended, which a backgrounded ship is not.

### CREATE

- [x] `Publish-LintGateProgress` / `Clear-LintGateProgress` in `scripts/lib/gate-lib.ps1`, called around the lint child in `Invoke-WorkflowGates`, guarded on the function and on gate depth 1
- [x] Rebuild the `dkj-policy` mirror of `gate-lib.ps1`
- [x] Bring the three places that state "two publishers" up to date: the 05-15 lens, the `publish-background-run.ps1` header, and part 5 of `adopt-dkj-policy`

### TEST

- [x] `gate-lib.tests.ps1`: a record is live WHILE the lint child runs, carries no counts, and is gone after a pass and after a fail; a cache hit and a nested (depth 1) run publish nothing
- [x] `gate-lib.tests.ps1` green, 201 asserts, including the mirror byte-identity assert

### DEPLOY: fix/2173-lint-gate-progress-record

The statusline no longer goes blank while a ship runs its lint gate. The lint gate is the step that runs
first, and on the measured ship (PR #2169) it took 78 seconds while publishing nothing, so a backgrounded
ship showed only its context line for exactly the stretch a reader is watching for -- and where the test
suites were already proved for the tree, the one long publisher that did exist never fired either, leaving
the whole pre-CI phase silent. `Invoke-WorkflowGates` now publishes a `lint gate (integrity check)` record
around its child call and removes it when the child returns, pass or fail.

It is an elapsed readout with no bar, and that is a decision rather than a shortfall: the integrity check
has no total number of checks to publish, and a bar over its very uneven checks would sit still for most of
the run. It publishes only at the top level of gate nesting, so the many suites that drive this function
over a fixture lint stay silent instead of repainting the test gate's own bar. `cut-release.ps1`'s separate
lint call is not covered.

The failure it prevents, named: a maintainer backgrounding a ship, seeing a blank statusline for ~90
seconds, and reasonably concluding the run had stalled.

**Score:** 3

#### What makes this deploy extra special

N/A -- nothing here needs a consumer to act. The progress bar and its statusline adoption are not in a
released version yet, so no consumer has the bar turned on to find this step missing from it.

**Score:** N/A

#### Pull Request

The lint gate publishes a progress record, so the statusline is no longer blank for the first part of a ship

