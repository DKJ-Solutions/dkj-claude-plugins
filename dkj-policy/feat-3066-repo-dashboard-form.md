## feat/3066-repo-dashboard-form

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

Closes #3066. The owner's decision (October 16, 2026): every repo's Repo dashboard takes the one form
`dkj-brandbook` lays down. That form was released as `house-style-v4` the same day, so this branch takes
the new copy and moves both pages the plugin source serves onto it.

#### A visible result

The placeholder page and the connector dashboard are judged by eye, so this branch stops before the merge
and the checkout stays on it until the owner has looked.

### CREATE

- [x] Repoint the `house-style` skill to `house-style-v4` (tag, commit, the stylesheet's checksum), and
      replace both vendored `house-style.css` copies. `house-theme.js` and the retired token names did
      not change at v4.
- [x] Item 1: the dkj-solutions README states the rule under "The dev-preview hook".
- [x] Item 2: the skill names the Repo dashboard pattern and the stylesheet-only reference page.
- [x] Item 3: the placeholder page (`dev-preview-placeholder.ps1`) takes the form: the repo name as the
      eyebrow, the fixed `h1`, the two setup cards in the data cards' place, an "About this repo" facts
      card and the footer note. No tiles, because a placeholder has no lists to count.
- [x] Item 4: the connector dashboard takes the form: the slug as the eyebrow, the fixed `h1`, the lead,
      the tiles, the warning line as `.msg--warn`, the two data cards with card heads, an "About this
      repo" facts card, and the footer note, which now carries the re-run link. The band, the header rule
      and the card accents are gone, because the form carries no decoration of its own.
- [~] Item 5, a gate that flags a dashboard departing from the form: dropped. The form is a block order
      and a set of house classes in HTML that each repo builds its own way (React, a Python string,
      PowerShell), so a pattern grep would either miss the departures or flag every build. The issue
      leaves the call to the implementer.

### TEST

- [x] `check-house-style.tests.ps1`: 58 passed. The gate on this tree holds at `house-style-v4`.
- [x] `dev-preview-sessionstart.tests.ps1`: 104 passed, now also asserting the form on the placeholder.
- [x] `connector-dashboard.tests.ps1`: 117 passed, now also asserting the form and its block order.

### DEPLOY: feat/3066-repo-dashboard-form

In this repo, the connector dashboard is now a Repo dashboard in the house form: an eyebrow, the fixed
`h1`, the tiles, the two data cards and an "About this repo" facts card. The re-run link has moved into
the footer note. The `house-style` skill and both vendored copies are on `house-style-v4`.

**Score:** 2

#### What makes this deploy extra special

Every DKJ-Solutions repo that states no dev preview now gets a placeholder in the one Repo dashboard
form. The `house-style` skill now points at `house-style-v4` and names the Repo dashboard pattern, so a
session building a repo's dashboard starts from that form.

**Score:** 3

#### Pull Request

Repo dashboard: every repo's index follows the house-style form (house-style-v4)

