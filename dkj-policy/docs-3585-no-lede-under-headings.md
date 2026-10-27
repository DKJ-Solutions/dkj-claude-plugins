## docs/3585-no-lede-under-headings

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

#3585 (Dave, every DKJ-Solutions product): no intro paragraph under a page heading; what a page is for goes
in its `<meta name="description">`. The rule alone would contradict the README's own Repository pattern
(an `h1` and a lead) and the hub's page shell, which draws `-Lead` under every `h1`, so all three change
together. That makes it a visible result: parked for the owner's look, no PR until then.

### CREATE

- [x] House-style README: rule 5 under "How to use it", the Repository page's row 0, and the section page's line
- [x] `house-style` skill, "Density": the bullet that banned only a REPEATING intro now bans any intro
- [x] `patterns/repo-repository.html`: the lead moves into `<meta name="description">`
- [x] `general-pages-lib.ps1`: `Format-GeneralPageHtml` writes `-Lead` as the description, tags stripped,
      never as `<p class="lead">`; `Format-RepoHomeHeadHtml` draws no lead
- [x] Tests: the six asserts that pinned an on-screen lead now pin the description, plus three new ones

### TEST

- [x] Gates left to `ship-pr` once the owner has looked (the sweep's step 4: a visible park runs none)

### DEPLOY: docs/3585-no-lede-under-headings

A hub page now opens on its `h1` and goes straight to its content: the one-line lead that stood under
every heading (a plugin's page, a section's page, a suite's page, Repository) is gone from the screen and
is the page's `<meta name="description">` instead. The house-style rules say the same for every
DKJ-Solutions app: no intro or explainer paragraph under a page heading, because screen height is scarce
([#3585](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3585)).

**Score:** 3

#### What makes this deploy extra special

Nothing beyond the entry above: one line per page moves from the screen into the page's metadata.

**Score:** N/A

#### Pull Request

House style: no intro paragraph under page headings

