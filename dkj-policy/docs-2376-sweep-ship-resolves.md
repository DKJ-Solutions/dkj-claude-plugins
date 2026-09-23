## docs/2376-sweep-ship-resolves

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

#2376: `sweep-issues` step 5 prescribed a bare `ship-pr.ps1`, which `open-pr`'s resolves gate refuses on
every sweep branch. Verified in this session: the first ship of a sweep branch (#2304 step 2) was refused
with exactly the reported message. The report's open question -- does a sweep ever ship a branch that
does not resolve its issue -- is answered by the same session: #2304's steps 2 and 3 were partial steps
and shipped with `-NoResolves`.

### CREATE

- [x] Step 5's command carries `-Resolves <n>`, with `-NoResolves` named for a partial step; step 6 points
  at the same command

### TEST

- [x] Gates run by `ship-pr` itself (no pre-run, see #2372)

### DEPLOY: docs/2376-sweep-ship-resolves

`sweep-issues` told a session to ship with a bare `ship-pr.ps1`, which `open-pr`'s resolves gate refuses on
every sweep branch, because the branch and its entry always name the issue. Step 5 now prints
`ship-pr.ps1 -Resolves <n>`, names `-NoResolves` for a branch that is only one step of a larger issue, and
step 6 points at the same command.

**Score:** 2

#### What makes this deploy extra special

A session sweeping a consumer's backlog no longer loses a round trip on every issue to a refusal the
skill's own command caused.

**Score:** 2

#### Pull Request

sweep-issues: the ship lines name -Resolves, so a sweep branch passes open-pr's resolves gate

