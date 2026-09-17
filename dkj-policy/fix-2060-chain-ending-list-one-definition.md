## fix/2060-chain-ending-list-one-definition

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

Correct the chain-ending list (park-cycle out, park-branch in) by giving closeout-lib the single definition both the instrument and the suite read; pin it against a tree-wide grep so a sixth caller cannot drift.

### CREATE

- [x] `closeout-lib.ps1`: `Get-ChainEndingScripts` -- the five callers named once, in the file they all dot-source
- [x] `measure-closeouts.ps1`: read that list instead of the hand-typed regex; a tree that cannot answer is reported and not measured
- [x] `measure-closeouts.ps1` header: the population paragraph no longer spells the five out, and the day's figures carry what re-measuring them showed
- [x] mirrored both into `plugins/dkj-policy/scripts/` via `build-shared-scripts.ps1`

### TEST

- [x] `closeout-lib.tests.ps1`: the declared list equals the suite's own `$callers`, AND equals the scripts a tree-wide scan finds calling `Write-CloseOutReceipt -Cite` -- so a sixth chain ender cannot land silently
- [x] `closeout-measure.tests.ps1`: two fixture sessions -- a park (must count) and an autopark (must not) -- asserted as membership rather than as a rate
- [x] proved the new asserts discriminate: the old script on the same fixture reads over-six 1, over-ceiling 2, median 5 against the new 0 / 1 / 2
- [x] measured the repair against this machine's real corpus, one frozen snapshot, old filter vs new
- [x] lint gate green; both suites green (92 pass / 24 pass)

### DEPLOY: fix/2060-chain-ending-list-one-definition

The instrument the close-out ceiling is measured with was filtering on a hand-typed list of "chain-ending
scripts" that was wrong in both directions: it named `park-cycle.ps1`, which the autopark Stop hook runs
after every turn and which prints no receipt, and it omitted `park-branch.ps1`, which prints one -- so
close-out shape C was outside the governed population and ordinary turns were candidates for it. The list
now exists once, as `Get-ChainEndingScripts` in `closeout-lib.ps1`, the file those callers already
dot-source, and the suite holds that definition against a scan of the tree, so a sixth chain ender cannot
be added without going red.

Re-measured over one frozen snapshot of this machine's corpus, old filter against new: the population did
not move (n=252 both) and one session's anchor did -- over-ceiling 193 to 192, over-six 120 to 119. Small
because `park-cycle` reaches a transcript almost never (a Stop hook runs it, not a tool call) and every
park session here had already run another chain ender. So the committed baseline is deliberately left as
it stands; what was wrong was the definition, not the recorded number.

The report's second finding does not stand: `-UpdateBaseline` writes the flat shape the committed baseline
carries, and only `-Json` emits the nested `All`/`CloseOuts`. Nothing is stale there.

**Score:** 2

#### What makes this deploy extra special

N/A -- an instrument used inside this repo to evaluate its own close-out rule. A consumer running the
workflow gets the corrected filter with the next release, but nothing they do changes on account of it.

**Score:** N/A

#### Pull Request

measure-closeouts reads the chain-ending list from one definition
