## docs/2014-bwj-chapter-skill-counts

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

#### What #2014 reported, and the one thing it got wrong

`plugins/dkj-policy/README.md:98`'s `dkj-policy-bwj` row was stale on two counts it states outright:
*"in three chapters"* (the theme lifecycle, chapter four since #1965, missing entirely) and
*"Two skills"* (the directory holds four). Both confirmed against the tree.

The issue's premise about the root `README.md:339` did **not** need acting on: #2012's branch had
already corrected that row to four chapters and four skills. My first reading said otherwise because
this checkout's base was 14 commits behind `origin/main`; `new-branch`'s stale-base refusal is what
caught it, before anything was cut.

**What the issue got wrong is its reason for leaving the reach axis alone**: it says the cell *"is
silent on how many repos this plugin reaches"*. It is not -- it opens *"the binding rules its two
Shopify store repos (smartwatchbanden, xoxowildhearts) operate under"*, which commit `b9b2a65a`
(September 14, 2026, #1982) made incomplete for ticket handling. That is a third staleness inside the
one sentence being rewritten, so it is corrected here rather than left behind for the same class of
issue to be filed a third time. This table has two columns, so unlike the root README -- which parks
the nuance in its enablement column -- the per-chapter reach goes in the description cell itself.

#### What is deliberately NOT in this branch

The **seam list** is the same chapter-four gap one axis over, and it is stale in three documents
#2014 never named: `dkj-policy-bwj/README.md:47` (*"exactly three seams"*), that plugin's
`plugin.json` description, and the root `marketplace.json` description -- each claiming three seams in
a string that says *"Four chapters"* and describes the theme lifecycle in full. Line 30 of the same
README enumerates *"the last two"* chapters and names three. Filed as
[#2017](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2017) rather than folded in, the
same way #2012 handed this cell on rather than widening itself.

### CREATE

- [x] Verify both counts against the tree -- `dkj-policy-bwj/README.md`'s chapter table (four, naming
      `THEME-LIFECYCLE-portable.md`) and `dkj-policy-bwj/skills/` (four) are the authority; both
      manifests already say *"Four chapters"*.
- [x] Rewrite `plugins/dkj-policy/README.md:98`: four chapters, the theme lifecycle's own one-line
      description with its issue citation, the four skills named, and the per-chapter reach.
- [x] Restore the file to LF after the edit -- the first write converted all 302 lines to CRLF, which
      `.gitattributes` (`* text=auto eol=lf`) normalizes on checkin but should not sit in the working copy.
- [x] File the adjacent seam-list staleness as #2017 instead of widening this branch.

### TEST

- [x] `check-plugin-integrity.ps1` -- the dead-link scan over the four issue URLs added to the cell,
      run as part of the gate below.
- [x] Lint + tests via `open-pr.ps1`.

### DEPLOY: docs/2014-bwj-chapter-skill-counts

The `dkj-policy` README's `dkj-policy-bwj` row now states what that plugin actually is: **four**
chapters rather than three -- the theme lifecycle, added on #1965, was missing from the row entirely --
and **four** skills rather than two, named. The same sentence also stopped claiming the codex binds
only BWJ's two Shopify store repos: since `b9b2a65a` the ticket-handling chapter also binds this
plugin's own source repo, and the row now says the reach differs per chapter.

A reader of this README was being told a plugin has three chapters and two skills while its own
README, its `plugin.json` and the marketplace manifest all said four and four -- so the one page a
consumer reaches from the workflow plugin was the page that disagreed with every other.

**Score:** 2

#### What makes this deploy extra special

A consumer deciding whether to enable `dkj-policy-bwj` reads this row and was under-counting what it
carries -- most consequentially, that a chapter exists which deletes themes from a live store's
estate. Nothing they run changes; what they know before enabling does.

**Score:** 2

#### Pull Request

the dkj-policy README's bwj row states four chapters and four skills
