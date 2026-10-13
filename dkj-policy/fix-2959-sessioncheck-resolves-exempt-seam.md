## fix/2959-sessioncheck-resolves-exempt-seam

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

#### The inbound report, verified against the tree (#2959)

The symptom stands: xoxowildhearts PR #422 carried `Closes #417`, the merge closed the issue before
its go-live block was posted, and `asana-closed-message` posted a bare closed message. The reasoning
does not: "nothing enforces the last arrow" overlooks that this plugin's rule is that an Asana-linked
issue is never closed by a merge at all (`-NoResolves`, WORKFLOW-portable.md step 4), and that
dkj-policy's resolves gate has refused `Closes #<n>` on such an issue since #2120 -- in a repo that
states `Get-ResolvesExemptMatchers`. smartwatchbanden states it; xoxowildhearts never did, because
adopt-bwj-development proposes that seam rather than placing it, and nothing reported its absence.

So the proposed repair (a go-live-block check inside ship-pr) is not built: with the seam stated the
merge closes nothing, and the issue's close is a person's act after the block. The gap is the silent
absence, and it is closed where the other store prerequisites are already reported.

### CREATE

- [x] `closed-message-sessioncheck.ps1` gains finding 4: in the two stores, a `scripts/repo-config.ps1`
      that defines no `Get-ResolvesExemptMatchers` is an `[ERROR]` line naming adopt step 2. Read as
      text, never dot-sourced; a commented-out definition does not count; no config at all is silent.
- [x] The README hooks row, WORKFLOW-portable.md's resolves-gate paragraph and adopt-bwj-development
      step 1's list of what the check reports say so.
- [x] Filed #2960: the README hooks row counts two hooks where hooks.json registers three.

### TEST

- [x] `closed-message-sessioncheck.tests.ps1`: 26 passed, 0 failed (8 new asserts: the measured case,
      the remedy, a commented-out definition, exit 0, an indented CRLF definition and a global:-scoped one
      are silent, a longer name is not the seam, silent outside the stores).
- [x] Probed against xoxowildhearts' real `scripts/repo-config.ps1` (read through the API): the hook
      prints the new `[ERROR]` line.

### DEPLOY: fix/2959-sessioncheck-resolves-exempt-seam

The bwj-development session check now reports a store whose `scripts/repo-config.ps1` states no
`Get-ResolvesExemptMatchers`. Without that seam dkj-policy's resolves gate lets a pull request close an
Asana-linked issue, so the merge closes it before its go-live block is on it and the Asana task gets a
bare closed message, as measured in xoxowildhearts (#2959).

**Score:** 2

#### What makes this deploy extra special

A store that never stated `Get-ResolvesExemptMatchers` is told so at session start, so a merge can no
longer close an Asana-linked issue before its go-live block is posted without anyone having been warned
(#2959).

**Score:** 3

#### Pull Request

closed-message-sessioncheck reports a store without Get-ResolvesExemptMatchers
