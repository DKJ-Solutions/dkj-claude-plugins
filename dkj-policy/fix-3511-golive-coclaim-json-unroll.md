## fix/3511-golive-coclaim-json-unroll

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

Inbound #3511, verified against the tree: `build-golive-block.ps1` wrapped its `ConvertFrom-Json`
pipeline in `@()`, which under 5.1 yields one element holding the whole list. The pickup hook runs the
same co-claim search but assigns the parsed value before wrapping it, so it was never affected (checked,
as the issue suggested). The same pattern elsewhere in the tree is either unrolled by an `if`/`return`
(prune-merged, tidy-machine, fold-changelog-entry, build-backlog-page) or is a separate subject
(cut-release's required-check read, filed as #3512).

### CREATE

- [x] Assign the peer list before wrapping it, in the repo's own idiom (claim-issue, gate-lib)
- [x] A behavioural assert from gh's JSON text in `asana-link-pickupcheck.tests.ps1`, and a source
      assert on the driver in `bwj-development.tests.ps1`

### TEST

- [x] The source assert matches the old line and not the new one; the old parse counts 1 for two issues
      and the new one counts 2 (5.1.26100). The suites run in ship-pr's gate.

### DEPLOY: fix/3511-golive-coclaim-json-unroll

`build-golive-block` no longer stops under Windows PowerShell 5.1 when the task's GID turns up in two
or more open issues. It now reads gh's search result one element per issue, so the one-task-one-issue
check runs instead of throwing on its number cast before the block is printed.

**Score:** 3

#### What makes this deploy extra special

In a store repo, `-OutFile` and `-Post` could not produce a go-live block at all when the task's GID
also turned up in other issues' text. It was measured on one with three such issues. From this release
on, the block is built and the co-claim check judges those issues as intended.

**Score:** 3

#### Pull Request

build-golive-block: unroll the co-claim JSON array under PowerShell 5.1

