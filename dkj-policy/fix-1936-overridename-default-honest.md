## fix/1936-overridename-default-honest

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

Default `-OverrideName` to `''` so a caller that exposes no root seam gets no "or pass X" clause at
all; the two callers that really spell it `-RepoRoot` pass it explicitly.

#### The choice, and why shape 1

#1936 left two shapes open and called the choice a real one. Shape 2 -- passing `-OverrideName` at
all 15 sites -- reaches the same output and leaves the trap armed for the sixteenth script. Shape 1
moves the defect to where it came from: the **default**. A parameter added precisely so the lib would
never name a flag it cannot know was handed a flag name to use when nobody says anything, which is
the same defect wearing the parameter as a disguise. With `''` a silent caller can no longer be given
a wrong answer, only a shorter one.

### CREATE

- [x] Reproduce #1936's measurement before repairing it -- the PowerShell parser over every `.ps1`
      under `scripts\` outside `lib\` and `tests\`, each `-OverrideName` (or the inherited default)
      held against the calling script's own param block. **27 call sites, 15 mismatched, and the
      same 15 scripts the issue names.** The symptom stands exactly as filed.
- [x] Default `-OverrideName` to `''` in `Resolve-RepoRootOrFail`
      ([`scripts/lib/check-report-lib.ps1`](../scripts/lib/check-report-lib.ps1)), and make every
      clause that quotes a seam conditional on it being non-empty -- the `'override'` branch, the
      cause line, and the remedy line.
- [x] `new-branch.ps1` and `fold-changelog-entry.ps1` -- the two callers that genuinely expose
      `-RepoRoot` -- pass `-OverrideName '-RepoRoot'` explicitly, which is what the parameter's own
      docstring says it is for.
- [x] Record the measurement in the docstring, which argued from the old default.
- [x] Rebuild the plugin mirrors (`build-shared-scripts.ps1`): 5 updated.

### TEST

- [x] `check-report-lib.tests.ps1` -- **254 pass, 0 fail.** Four asserts on the existing seamless
      child (no `or pass` clause, no `-RepoRoot` anywhere in the output, both real routes kept, the
      cause line drops the seam too), plus a **control child** passing `-OverrideName '-RootOverride'`
      so the four above cannot be satisfied by a function that has simply stopped offering the flag
      to anybody -- which would break the two correct callers silently.
- [x] The residual the `''` default cannot close -- a call site naming a flag it does not expose --
      is held by a parser sweep in that same suite, over the same 27 sites. It asserts **both**
      non-zero counts (12 naming a seam, 15 naming none), because a sweep that found nothing would
      pass the mismatch assert while measuring nothing.
- [x] Reproduced the issue's own case: `tidy-machine.ps1` run from a directory that is not a work
      tree now prints `Run this from inside the checkout, or set CLAUDE_PROJECT_DIR.` -- the two
      remedies that exist, and not the one PowerShell rejects.
- [x] Lint gate (`check-plugin-integrity.ps1`): 0 errors.

#### What the review chain changed

Victor, Edith and Sebastian ran in parallel on the diff. Sebastian: no findings -- the resolution
logic is untouched, so this is a messaging-only change that cannot let a caller reach a root it would
previously have been refused. Edith caught a wrong citation (`check-report.tests.ps1` for
`check-report-lib.tests.ps1`) and a comment that read as a contradiction; both repaired. Victor found
no correctness bug and three cleanup-class observations, and **two of them were false-positive risks
in the gate this branch adds**, so they were closed rather than shipped: the sweep now judges only a
STRING LITERAL argument (a future `-OverrideName $var` would otherwise be reported as a mismatch that
is not one) and states in a comment why the script-level param block is the right one to read. The
third -- the `'override'` arm's fallback being unreachable from today's tree -- got the two asserts
that were missing instead of being deleted, since it is reachable the moment a caller passes
`-Override` without naming a seam.

### DEPLOY: fix/1936-overridename-default-honest

`Resolve-RepoRootOrFail`'s refusal no longer offers `-RepoRoot` to the 15 of 27 callers that have no
such flag. That parameter exists because the lib cannot know which seam a caller spells -- and it
defaulted to `-RepoRoot`, right for the two scripts the docstring names and wrong for every script
meant to be run from inside the checkout, handed out to whoever did not think about it. Reproduced on
`tidy-machine.ps1`: of the three remedies printed, the middle one was rejected by PowerShell as an
unknown parameter, and it is the one that reads as the direct fix.

The default is now `''`, so an unnamed seam prints no seam. That closes the **class** rather than the
15 instances: a caller that says nothing can no longer be given a wrong answer, only a shorter one.
The two callers that really do expose `-RepoRoot` now pass it explicitly, which is what the
parameter's own docstring always said it was for.

**Score:** 2

#### What makes this deploy extra special

**Fourteen of the fifteen are plugin-carried** (all but `build-config-blueprint`, which is
source-only), so this is a refusal a consumer meets in their own tree, on their own machine, with no
source checkout to check it against -- `ship-pr`, `open-pr`, `prune-merged`, `tidy-machine`,
`park-branch`, `worktree-lane`, `cut-release` and the four `adopt-*` scripts among them. Every one
of them told a reader standing outside a work tree to pass a flag it does not have. Nothing is asked
of anybody: no re-install, no config, no migration. The remedy simply stops being a dead end, and
because the fix is a default rather than fifteen edits, the sixteenth script inherits it for free.

**Score:** 2

#### Pull Request

Resolve-RepoRootOrFail no longer names a flag the caller does not expose
