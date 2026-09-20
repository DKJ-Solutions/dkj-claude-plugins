## fix/2174-reap-orphaned-tmp-record

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

#### The repair, and the one it deliberately is not

`Write-RunProgress` writes `<id>.json.<pid>.tmp` and moves it into place -- the atomic write that
makes a torn read impossible. `Get-LiveRunProgress` globs `*.json`, which that name is not, so a
producer killed between the write and the move leaves a file both reaping paths sit inside a loop
away from. Issue #2174 measured one: 232 B, a day old, from a test-gate run whose pid was long gone.

Widening the glob was the cheaper repair and it is refused, on the lib's own stated ground -- a
record it cannot parse is *skipped, not deleted*, because a reader that deletes what it cannot read
destroys evidence. So the sweep is keyed on the exact name **this lib writes** and on nothing else.

### CREATE

- [x] `Remove-OrphanedRunProgressTemp` in `scripts/lib/run-progress-lib.ps1`: sweep `*.tmp` whose
      name matches `.json.<pid>.tmp`, reaping past the hard age cap or once that pid is gone
- [x] `Get-LiveRunProgress` calls it on the same pass -- the same party that has just proved each
      record dead, which is the reason reaping lives there rather than in a sweeper
- [x] the mirrors rebuilt (`build-shared-scripts.ps1`), since this lib ships in two plugins

### TEST

- [x] four cases added to `scripts/tests/run-progress.tests.ps1`: the orphan goes, a live writer's
      own tmp stays, the age cap still fires over a live pid, and a `.tmp` this lib did not write is
      left alone
- [x] the suite is green (63 asserts), and the lint + test gate runs at the push

### DEPLOY: fix/2174-reap-orphaned-tmp-record

The progress root no longer grows one small file per killed producer. `Get-LiveRunProgress` reaped
only `*.json`, so the `.tmp` a producer abandons when it is killed between the write and the move
was never looked at again -- and a killed producer is ordinary here, since a backgrounded ship dies
with its harness. It is swept now on the same pass, keyed on the name this lib itself writes and on
the pid embedded in it, so a `.tmp` somebody else put there is still evidence rather than litter.

Cosmetic and slow rather than visible: the statusline never parsed these, so no bar was ever wrong.
The failure it prevents is unbounded accumulation in `%LOCALAPPDATA%\dkj-run-progress\`.

**Score:** 1

#### What makes this deploy extra special

Nothing reaches a subscriber of the service: this is a per-developer cache directory on the machine
running the workflow, and nothing it holds is published, rendered or shipped.

**Score:** N/A

#### Pull Request

An orphaned .tmp progress record is reaped instead of accumulating forever
