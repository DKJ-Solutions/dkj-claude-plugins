## fix/1926-machineonly-without-checkout

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

#1926 asks a question rather than reporting a defect: should `tidy-machine -MachineOnly` run without a
checkout? It also says what answering it costs -- *"whoever takes it should check each machine-half lane
for a `$repoRoot` use rather than assuming the switch is clean."* That measurement came first, and the
switch is **not** clean:

| lane | `$repoRoot` use | needs a checkout? |
|---|---|---|
| 7 -- `~/.claude` administration | none; delegates to `check-claude-home.ps1`, which resolves tolerantly already and falls back to `$PSScriptRoot` | no |
| 8 -- orphaned install records | `Get-InstallRecord -RepoRoot`, then reads only `AllRecords`/`Exists`/`Readable` -- never the repo-scoped half | no |
| 9 -- plugin/marketplace staleness | delegates to `plugin-versions.ps1` -> `Get-EnabledPlugins -RepoRoot`; the question IS "this checkout's plugins" | **yes** |
| 10 -- fixture trees | none; walks the scratch root | no |
| 11 -- retired-name records | `Get-InstallRecord` as above, **plus** `$rootKey`, to mark findings belonging to another checkout | degrades honestly |
| 12 -- payload trees | `Get-InstallRecord` as above | no |

So the answer is yes, with lane 9 named as the exception rather than left to fail inside its child. The
argument for is the switch's own documented purpose and the skill page calling this *"the closing tidy-up
of a working session"*; the argument against -- one resolution up front is simpler than a conditional one
-- is answered by putting the conditional in one place, at the top, rather than in six lanes.

#### What #1917 left, and what this branch does not re-litigate

The dead `if (-not $repoRoot) { $repoRoot = (Get-Location).Path }` is already gone and the behaviour it
pretended to grant was never granted. Nothing here re-argues that. What is added is the tolerance itself,
narrowed to the one half that can carry it.

### CREATE

- [x] Measure every machine-half lane for a `$repoRoot` use -- the table above; #1926's own precondition
- [x] Resolve per half: `Resolve-RepoRootOrFail` under `$runCheckout`, `Resolve-CheckRoot` otherwise. The flag block moves above the resolution, since the resolution now depends on it
- [x] `$recordRoot` -- the `$PSScriptRoot` stand-in for the three lanes that hand `Get-InstallRecord` a root only to read a field that does not depend on it. Copied from `check-claude-home.ps1`, which already answers this exact call the same way
- [x] Skip lane 9 by name with the reason stated; guard the `repo-config.ps1` read (`Join-Path` refuses an empty `-Path`) and the banner (an empty `repo root:` reads as a failed resolution)
- [x] Lane 11: `$rootKey` off `$recordRoot`, plus one line so *"another checkout"* does not send the reader hunting for which one is this one
- [x] Document the new contract -- the `.PARAMETER MachineOnly` block and the skill page
- [x] Mirror to `plugins/dkj-policy/` via `build-shared-scripts.ps1`

### TEST

- [x] `tidy-lib.tests.ps1` section 11: three structural asserts (both resolvers wired to their own half; no possibly-null root reaching `Get-InstallRecord`'s Mandatory `-RepoRoot`) and the first two asserts in this file that RUN the script -- `-MachineOnly` reaching lane 12 and exiting 0 in a non-repo fixture, `-CheckoutOnly` still refusing there. 89 passed, 0 failed, 2.8s
- [x] Ran by hand from a non-repo scratch directory: all six lanes, exit 0, lane 9 skipped with its reason
- [x] Ran by hand from inside the repo: banner, lane 9 and every tally unchanged
- [x] Lint gate + all suites green

### DEPLOY: fix/1926-machineonly-without-checkout

`tidy-machine -MachineOnly` now runs with no checkout at all -- from a home directory, a scratch
directory, anywhere. It never did, despite a fallback that read exactly as though it did: the old
`if (-not $repoRoot) { $repoRoot = (Get-Location).Path }` could only fire on an empty string, and the
line above it threw on `$null` first, so the guard caught a state that could not occur. #1917 removed
that dead line and left the question standing; this answers it.

The root is now resolved per half rather than once up front -- the refusing resolver for the six
per-checkout lanes, whose subject a checkout genuinely is, and the tolerant one otherwise. Five of the
six machine lanes need no repo, which was measured rather than assumed: lane 7 delegates to a script
that already resolves tolerantly, lanes 8, 11 and 12 hand `Get-InstallRecord` a root only to read the
one field of its answer that is not filtered by it, and lane 10 walks the scratch root. The sixth,
lane 9, asks how far behind *this checkout's* plugins are, so it is skipped by name and says why --
rather than left to refuse inside `plugin-versions.ps1`, where the refusal is worded for somebody who
ran that script directly and would read, from here, as the whole run having failed.

Every other invocation refuses exactly as before, and the suite now pins both directions.

**Score:** 2

#### What makes this deploy extra special

A consumer's closing tidy-up no longer has to be run from inside a repository to answer the questions
that were never about one. `tidy-machine` ships in `dkj-policy`, and `-MachineOnly` is the mode whose
whole subject is the machine -- stale install records, plugin staleness, extracted payload nothing
points at, leftover fixture trees. Standing in a home directory and asking for them used to end in a
raw `You cannot call a method on a null-valued expression`; since #1917 it ended in a stated refusal;
now it answers.

**Score:** 2

#### Pull Request

tidy-machine -MachineOnly runs without a checkout

