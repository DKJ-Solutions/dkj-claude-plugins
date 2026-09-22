## fix/2322-resolve-trunk-ref-helper

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

#### The size, as measured on pickup

#2322 counts three copies of the idiom. Two of them are on `main`, both in `scripts/lib/park-lib.ps1`.
The third, `open-pr.ps1`'s overlap scan, exists only on the parked branch
`origin/feat/2315-open-pr-overlap-scan`, which has no PR and belongs to another account. That branch
is not touched here. `open-pr.ps1` already dot-sources `park-lib.ps1`, so its copy can call the
helper once both land. The other trunk-ref sites (`open-pr.ps1`'s subject loop and `claim-issue.ps1`'s
multi-ref lists) loop over candidate refs rather than verify-then-fallback, so they are not copies of
this idiom.

### CREATE

- [x] `Resolve-TrunkRef` in `park-lib.ps1`: returns `refs/remotes/origin/<trunk>`, else the bare name, else `$null`
- [x] `Get-GitParkBacking` and `Get-BranchMachineLocalFindings` call it in place of their inline copies
- [x] plugin mirror regenerated with `build-shared-scripts.ps1`

### TEST

- [x] `backing-gate.tests.ps1` section 10 asserts the helper's three answers directly; backing-gate, machine-local-gate, park-branch and park-cycle suites all green

### DEPLOY: fix/2322-resolve-trunk-ref-helper

The "use `refs/remotes/origin/<trunk>` where it verifies, otherwise the bare local name" resolution
was written out twice in `park-lib.ps1`, once for the backing gate and once for the machine-local
check. Both copies now call one helper, `Resolve-TrunkRef`, which returns `$null` when neither ref
verifies, so the "not measured" cases are unchanged. The ordering matters because a local trunk behind
`origin` over-reports a branch's work (#1399). With one definition there is no second copy to get
wrong. Behaviour is unchanged, and `backing-gate.tests.ps1` now asserts the helper directly.

**Score:** 1

#### What makes this deploy extra special

N/A. The lib is mirrored into `dkj-policy`, but nothing a consumer runs behaves differently.

**Score:** N/A

#### Pull Request

park-lib resolves the trunk ref through one Resolve-TrunkRef instead of two inline copies

