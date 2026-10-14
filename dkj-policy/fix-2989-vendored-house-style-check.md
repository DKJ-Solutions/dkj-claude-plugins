## fix/2989-vendored-house-style-check

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

After #2986 repointed the `house-style` skill to `house-style-v2`, the two files this repo vendors for
the connector dashboard (`scripts/dashboard/house-style/`) stayed on v1. Nothing noticed until the owner
missed the new settings button (#2989). Verified on `main`: the copy now matches v2, but the skill's
repoint procedure still names only the links, the commit and the checksums, and no check ties the
vendored copy to them. The fix is a check that does this, plus one clause in the procedure.

### CREATE

- [x] `connector-dashboard.tests.ps1`, group 1e: each vendored file's sha256 must equal the row the
      skill's table pins for it, read from `SKILL.md` itself so the table stays the single copy.
- [x] `house-style/SKILL.md`, "Changing the house style": a repoint also replaces the source repo's
      vendored copy, and that suite holds it there.

### TEST

- [x] `connector-dashboard.tests.ps1` green standalone, group 1e 4/4.

### DEPLOY: fix/2989-vendored-house-style-check

The connector dashboard's test suite now checks that its vendored copy of the house style hashes to
the checksums the `house-style` skill pins. The skill's repoint procedure now names that copy. The
next repoint to a new `house-style-v<N>` tag therefore turns the suite red until the dashboard's two
files move as well. Before, they stayed on the old tag without anyone noticing (#2989).

**Score:** 1

#### What makes this deploy extra special

N/A: the check and the vendored copy exist only in this repo. The sentence added to the skill page
addresses whoever performs a repoint here, and a consumer's use of the skill is unchanged.

**Score:** N/A

#### Pull Request

Hold the dashboard's vendored house style to the skill's checksums
