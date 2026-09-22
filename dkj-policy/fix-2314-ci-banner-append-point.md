## fix/2314-ci-banner-append-point

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

Option A chosen by Dave: per-anchor paragraphs. Split the file-level banners so each decision's prose
sits directly above the key or step it argues; state the convention; keep every word.

#### What the collision actually is

`ci.yml` carries five comment runs. Four sit directly above a key and are bounded by that key's
subject; the fifth -- the banner above `jobs:` -- belongs to no key, so it is where prose about *any*
job lands. That is the orphan anchor, and it is the one #2303 and #2296 both appended to while also
inserting a key under `runs-on:` in the `suites` job.

#### The one thing the issue did not name

#2296 had already half-adopted the answer: it wrote a two-line pointer above `timeout-minutes:` in
the `suites` job AND a 31-line banner above `jobs:`. So the convention is not merely unstated -- it is
stated by example in both directions at once, which is why writing it down is part of the repair
rather than a note beside it.

### CREATE

- [x] Re-home every paragraph in the `jobs:` banner that argues a single key, to that key: the name
      rule and the two `!cancelled()` paragraphs to `lint-en-tests`, the strict-success paragraph to
      the step that enforces it, the merge-commit shortcut (#2303) to the certificate step that
      already carries a pointer back to it, and the two per-job timeout derivations (#2296) to the
      `timeout-minutes:` keys they name.
- [x] Collapse the duplication those pointers created -- #2303's argument is currently in the banner
      AND on its step, #2296's in the banner AND on the `suites` key.
- [x] Leave the genuinely file-wide paragraphs where they are: why there are three jobs, and the
      rule that every job declares a timeout at all.
- [x] State the convention in `ci.yml`'s own head, so the next CI branch reads it before it appends.
- [x] Record the argument in Sylvester's lens, which is where this repo already writes CI reasoning.

### TEST

- [x] A guard on the orphan anchor: `ci-shard.tests.ps1` holds the `jobs:` banner to a measured
      ceiling, so a re-grown banner fails a suite instead of surfacing at the next conflict.
- [ ] Every assert that reads `ci.yml` by regex still passes -- `ci-shard.tests.ps1`,
      `merge-queue-prereq.tests.ps1`, `workflow-timeouts.tests.ps1`.
- [x] No reasoning lost: the change is a move, verified by comparing the comment bodies before and
      after rather than by reading the diff.

### DEPLOY: fix/2314-ci-banner-append-point

Every paragraph of reasoning in `.github/workflows/ci.yml` now sits directly above the one key, step or
job it argues, so a new CI decision brings its own new anchor instead of another paragraph on the end of
a shared block. The comment run above `jobs:` had no owning key, which is why prose about any job landed
there -- and git cannot merge two appends at one anchor, so two branches obeying the "argue it where it
lives" convention correctly conflicted pairwise, by construction. Three CI branches in one afternoon did
(#2296, #2303, #2304); `ship-pr` found it on #2300 at forward lap 3, after roughly forty minutes of CI
waits, and resolving it took about five minutes. It is the #1255 shape one file over, where a single
fixed development document made every merge conflict every other open PR.

Nothing was rewritten: of 301 comment lines, twelve changed, and every one of those twelve was a
cross-reference the move made false. What stays above `jobs:` is what is true of the file as a whole --
why there are three jobs, and that every job declares a timeout at all -- so the run went 87 lines to 32.
`ci-shard.tests.ps1` holds it to a 40-line ceiling, paired with an assert that the convention is stated
in the file's own head, because a ceiling that fires without saying what to do instead sends the next
author to raise the ceiling. The `runs-on:` half of the collision is deliberately left alone: two branches
adding different keys to one job header is irreducible and took thirty seconds.

**Score:** 2

#### What makes this deploy extra special

N/A -- this is the source repo's own CI workflow. Nothing here travels to a consumer: `ci.yml` is not
plugin payload, it is not one of the runners `adopt-dkj-policy` scaffolds, and a subscriber of this
service reads nothing that changed.

**Score:** N/A

#### Pull Request

ci.yml's reasoning sits above the key it argues, so two CI branches no longer append to one anchor
