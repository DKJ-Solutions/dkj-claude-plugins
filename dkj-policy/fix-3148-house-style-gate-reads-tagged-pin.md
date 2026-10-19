## fix/3148-house-style-gate-reads-tagged-pin

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

#3148: between a merge that changes a house file and the cut, the skill page on `main` names the previous tag
beside the new checksums. The reason was verified before the repair: `reusable-house-style.yml` runs from `main`
and read the pin from that page, so the skill's sentence "no consumer reads this page from `main`" was false.
Of the issue's two directions this takes a third, which needs no change to the cut: the gate reads the page **at
the tag the page names**, where the tag and the checksums agree by construction.

### CREATE

- [x] `check-house-style.ps1 -SkillPath`: the page to read the pin from, defaulting to the one beside the gate
- [x] `reusable-house-style.yml`: read the tag from the page, sparse-check-out the page at that tag, pass it in
- [x] The skill page's "between the merge and the cut" paragraph says what the gate actually reads
- [x] `check-house-style.tests.ps1`: `-SkillPath` is honoured, and the workflow takes the tagged page. Also
      repaired: two statements glued on one line meant the "a repo-config.ps1 that throws" case never wrote its
      config, so that assert passed on the previous fixture's exit 2

### TEST

- [x] `check-house-style.tests.ps1`: 77 passed, 0 failed
- [x] Replayed the workflow's steps by hand against the files `v5.24.0` serves: the gate exits 1 against the
      page on `main` (the reported defect) and 0 against the page at `v5.24.0`

### DEPLOY: fix/3148-house-style-gate-reads-tagged-pin

The reusable house-style gate now reads its pinned checksums from the skill page as it stands at the tag that page names, not from `main` (#3148). Between a merge that changed a house file and the next cut, the page on `main` named the previous tag beside the new checksums, so a consumer vendoring exactly the released file failed the gate. `check-house-style.ps1` takes `-SkillPath` for this. The suite's "repo-config.ps1 that throws" case now really writes that config: it had passed on the previous fixture's exit code.

**Score:** 2

#### What makes this deploy extra special

A DKJ-Solutions repo calling `reusable-house-style.yml@main` no longer goes red after a house-style change is merged here and before it is released. Its vendored copy is held to the release it can actually fetch, and nothing changes on its side.

**Score:** 3

#### Pull Request

the reusable house-style gate reads its checksums at the tag the skill page pins

