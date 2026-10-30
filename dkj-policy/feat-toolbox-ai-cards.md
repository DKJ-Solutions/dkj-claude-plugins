## feat/toolbox-ai-cards

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

Maikel, October 30, 2026: an AI card on the Toolbox; its landing page a Claude card; Claude's landing page three
cards, Rules, Skills and Specialists. A visible result, so the branch waits for the owner's look before it merges.

### CREATE

- [x] `Get-HubGroups` takes a parent `Group`, and holds AI, Claude, Rules, Skills and Specialists as groups
- [x] A top-level group with no general page of its own is a hub card (`Format-HubPageCardsHtml`)
- [x] A group page lists its member groups, trails through its parents, and says so when it has nothing yet
- [x] Four icons: ai, claude, rules, skills (Specialists reuses its own)
- [x] The hub README names the AI card

### TEST

- [x] `dev-pages.tests.ps1` green (487 passed), with asserts for the AI card, the three levels and their trails
- [x] Served from this tree on :4910: `/`, `/ai`, `/ai/claude` and the three leaves all answer 200 with the right cards
- [ ] The owner has looked at the pages and approves them

### DEPLOY: feat/toolbox-ai-cards

The Toolbox has an AI card. Its page holds a Claude card, and Claude's page holds three: Rules, Skills and
Specialists, each a landing page of its own with nothing on it yet. Hub groups can now nest, so a group page may hold
other groups, and its trail runs through each of them (Tools > AI > Claude > Rules).

**Score:** 2

#### What makes this deploy extra special

Every repo's Toolbox shows the new AI card, though the pages under it are still empty.

**Score:** 2

#### Pull Request

An AI card on the Toolbox, with a Claude card holding Rules, Skills and Specialists

