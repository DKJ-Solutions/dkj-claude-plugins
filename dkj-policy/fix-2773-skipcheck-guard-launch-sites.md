## fix/2773-skipcheck-guard-launch-sites

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
> For tier 2 audiences: the user who relies on what this repo ships, and decides whether to take the next version -- a subscriber of a service, or the user of a tool, its own maintainer included. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

#2773: the "no gate that guards main passes -SkipCheck" guard only looked for the literal text. Checked
before the repair: the gate's `param([string[]]$SkipCheck)` is its only `-Skip*` parameter and is
positional, so `-Skip x`, a bare `x` or a splat would all reduce it. Two more things the report missed:
`open-pr.ps1` never launches the gate itself (`gate-lib.ps1`'s `Invoke-WorkflowGates` does), and the
proposed `-Skip\w*` over the whole file would trip on the callers' own `-SkipLint`/`-SkipTests`.

### CREATE

- [x] Rewrite the guard in `check-plugin-integrity-roster.tests.ps1` to scan for every line that launches
  the lint gate (`-File` beside the lint path, under `scripts/**` and `.github/workflows`, tests excluded)
  and assert nothing but a closer follows the path: nothing, `| Out-Host`, or `)` with no `,` after it.
- [x] Assert the scan finds the known launchers (`gate-lib.ps1`, `cut-release.ps1`, `ci.yml`), so a moved
  call cannot leave the guard asserting over nothing.

### TEST

- [x] Suite green, 62 of 62 asserts. The matcher was also run by hand on six crafted bypasses (`-Skip x`,
  a positional `x`, a splat, `, '-SkipC'` inside an array, and `), '-Skip'` / `)), '-Skip'` after
  gate-lib's quoting parens). The first draft let the `), '-Skip'` shape through, and the tightened rule
  refuses all six.

### DEPLOY: fix/2773-skipcheck-guard-launch-sites

The guard that keeps every merge path on the full lint gate now checks the line that launches the gate,
not the caller's text. Before, it only looked for the literal `-SkipCheck`, so an abbreviated `-Skip x`,
a positional argument or a splat would have reduced the gate unnoticed. It also read `open-pr.ps1`, which
never launches the gate. It now finds every launch under `scripts/` and `.github/workflows` and refuses
any argument after the lint path. This prevents a reduced gate on a merge path, which has not happened
yet ([#2773](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2773)).

**Score:** 1

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

check-plugin-integrity guard: check the gate's launch lines, not the literal -SkipCheck

