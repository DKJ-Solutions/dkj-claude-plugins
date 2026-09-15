## docs/2012-ticket-work-step-reach

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

Fixes #2012: three "ticket-work step ... BWJ's two Shopify store repos" sentences left stale by
`b9b2a65a` (which admitted this plugin's own source repo, `dkj-claude-plugins`, to the ticket-handling
chapter alone) and by #1982's sweep (which fixed the four portable law pages and `README.md:339`'s
enablement cell but never named these three prose sites). Also folds in the "also noticed" axis #2012
flagged on the same pass: `README.md:339`'s table row still opened "Three chapters" with
`THEME-LIFECYCLE-portable.md` (chapter four, added September 13, 2026) missing from the list entirely.

### CREATE

- [x] Fix `plugins/dkj-policy/CONTRIBUTING-portable.md:600` -- the worked-example sentence now names
      both BWJ's two store repos and this plugin's own source repo (ticket handling alone).
- [x] Fix `plugins/dkj-policy/README.md:210` -- same fix, same wording pattern.
- [x] Fix `README.md:297` (root) -- same fix; also corrected the stale
      `DaveKJohn/claude-code-specialists` issue-1382 URL in the same sentence to
      `DKJ-Solutions/dkj-claude-plugins`, since that citation was being edited for another reason
      anyway (the repo-citation rule in `CLAUDE.md`: corrected on edit, not swept).
- [x] Fix `README.md:339`'s table row -- "Three chapters" to "Four chapters", added the missing
      **the theme lifecycle** chapter description (backup-and-rotate at the release cut, sweep spent
      previews after the live push, both keyed on a reserved name prefix), and added the
      sync/theme-lifecycle chapters' shared `dkj-subagents-shopify` dependency note.
- [x] File the unrelated staleness noticed while fixing the chapter count: `plugins/dkj-policy/README.md:98`
      still says "in three chapters" and "Two skills" for `dkj-policy-bwj` -- same class of drift,
      but a distinct site #2012 never named, so filed separately rather than folded in here (#2014).

### TEST

- [x] `scripts/lint/check-plugin-integrity.ps1` -- dead-link and manifest checks, doc-only diff.
- [x] Full test suite (`scripts/tests/*.tests.ps1`), via `open-pr.ps1`'s pre-flight gate.

### DEPLOY: docs/2012-ticket-work-step-reach

Three prose sites describing the `dkj-policy-bwj` ticket-work step still said it reached "BWJ's two
Shopify store repos" after commit `b9b2a65a` widened that one chapter to a third repo
(`dkj-claude-plugins`, this plugin's own source) on September 14, 2026 -- a related but distinct
staleness from the one #1982 fixed the same day, since #1982 never named these three files. All three
now state the real reach. A fourth, unrelated staleness on the same row `README.md:339` -- the chapter
count still read "Three chapters" with the September 13 theme-lifecycle chapter missing from the list
-- is fixed in the same pass, since #2012 explicitly asked for it on the ground that whoever picked
this up would already be editing that exact cell. One further site of the same chapter/skill-count
drift, `plugins/dkj-policy/README.md:98`, was noticed but not named by #2012 and is filed separately
as #2014 rather than folded into this branch's scope.

**Score:** 1 -- corrects stated reach in prose; no script, gate or check reads these sentences, so
nothing behaves differently for this repo's own maintainers.

#### What makes this deploy extra special

`CONTRIBUTING-portable.md` is portable payload that ships to every consumer running `dkj-policy`. A
subscriber reading its ticket-work-step section previously saw an inaccurate scope for
`dkj-policy-bwj`'s worked example; it now matches the gate `report-issue`/`adopt-dkj-policy-bwj`
actually enforce.

**Score:** 1 -- a subscriber who never reads that one paragraph is unaffected, and the gate itself was
already correct; this only fixes what the prose claims about it.

#### Pull Request

Sweep the ticket-work step's stale two-repo reach and README:339's missing fourth chapter

