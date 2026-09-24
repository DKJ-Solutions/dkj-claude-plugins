## docs/retire-root-readme

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

Dave, September 24, 2026: retire the root `README.md` entirely, with no stub (option A). Every section first
moves to the page that owns its subject, the same route #2171/#2179 took for `dkj-policy/README.md`.

### CREATE

- [x] Rehome each root section: marketplace architecture into `plugins/dkj-subagents/README.md`, consumption/adoption/teardown into `plugins/ADOPTION.md`, versioning and the skills policy into `plugins/dkj-policy/README.md`, repo-only facts into Tessa's and Sylvester's lenses
- [x] Delete `README.md` and repoint every live link, including the five absolute URLs in the `specialists-init` / `specialists-teardown` skill pages
- [x] Archived release notes: repoint to a permalink at `123878dd`, the precedent of `5a9c004c` and `170d5f99`
- [x] `check-plugin-integrity.ps1`: swap the retired root `README.md` for `plugins/dkj-subagents/README.md` in the consumer-facing set of checks 15/16
- [x] Copy edit (Edith) applied: an inventory line, a directional word, a self-reference

### TEST

- [x] Plugin integrity lint green locally (dead links, plugin-root links, consumer-doc set)

### DEPLOY: docs/retire-root-readme

The root `README.md` is gone. Its content now lives on the pages that own each subject: the marketplace
architecture in `plugins/dkj-subagents/README.md`; consumption, adoption, where it runs and the teardown gap in
`plugins/ADOPTION.md`; versioning and the skills policy in `plugins/dkj-policy/README.md`; the repo-only facts
(one product, one repository, the repo layout) in the technical-writer and system-administration lenses. Every
live link was repointed. The archived release notes now link to a permalink of the README as it last stood.
The lint's consumer-facing set now reads `plugins/dkj-subagents/README.md` where it read the root page.

**Score:** 3

#### What makes this deploy extra special

The repository's GitHub landing page no longer renders a README. A consumer finds the adoption and teardown
material in `plugins/ADOPTION.md`, and the links in the shipped `specialists-init` / `specialists-teardown`
pages now point there.

**Score:** 2

#### Pull Request

Retire the root README; rehome its content in the lenses and plugin pages

