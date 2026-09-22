## docs/2242-fold-stamp-heading-drift

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

Fixes #2242: sort the ~15 sites claiming the fold stamps the `Pull Request` heading -- current-tense
drift since the stamp moved to the entry's own heading on August 23, 2026 -- into current (fix),
historical (leave), and different-mechanism (leave: the lint's duplicate-section PR-link errors).

### CREATE

- [x] Classify and correct the current-tense sites in `scripts/lib/entry-scaffold-lib.ps1`,
      `scripts/release/fold-changelog-entry.ps1`, `scripts/lint/check-plugin-integrity.ps1` and
      `scripts/tests/entry-scaffold.tests.ps1`
- [x] Correct the two portable pages consumers read (`DEVELOPMENT-portable.md`,
      `CONTRIBUTING-portable.md`) and the `fold-changelog` skill page, which carried both answers
- [x] Correct the two current-tense sites in Rendall's repo lens (`specialist-05-06-lens.md`)
- [x] Sync the `plugins/dkj-policy/scripts/` mirrors via `build-shared-scripts.ps1`
- [x] File a separate issue for a real double-stamp bug found while verifying the fix (a
      pre-dossier entry now gets the merge date on both its heading and its closing line) --
      #2259, out of scope for this docs-only branch

### TEST

- [x] `scripts/lint/check-plugin-integrity.ps1` -- 0 errors
- [x] `scripts/tests/entry-scaffold.tests.ps1` -- all 838 asserts passed

### DEPLOY: docs/2242-fold-stamp-heading-drift

Corrects the tree's ~15-site drift about where the fold's merge stamp lands: the entry's own
`### DEPLOY:` heading since August 23, 2026, not the `Pull Request` heading that carried it from
August 19–23. Left untouched: passages that correctly describe that August 19–23 window as history,
and the lint's duplicate-section errors, which are about the closing PR *link* rather than the stamp.

**Score:** 3 -- self-contradicting comments and docstrings (a summary line disagreeing with its own
body) are exactly the kind of drift that misleads the next person to touch this code.

#### What makes this deploy extra special

`DEVELOPMENT-portable.md` and `CONTRIBUTING-portable.md` are the only description a consumer has of
where their changelog's ordering key lives; the stale text pointed at the wrong heading.

**Score:** 1 -- prevents a consumer debugging their changelog's ordering from looking at the
`Pull Request` heading, finding no stamp, and concluding the fold is broken.

#### Pull Request

Correct the stale 'Pull Request heading' claims about the fold's merge stamp

