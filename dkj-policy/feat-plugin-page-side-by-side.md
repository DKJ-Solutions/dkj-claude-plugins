## feat/plugin-page-side-by-side

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

The owner asked for the hub's plugin page (/plugins/<name>) to read on one 1300 x 900 screen, blocks side by
side rather than stacked.

### CREATE

- [x] `Format-PluginPageHtml`: the description and the machine state as two cards in one `.grid-2` row; the
  status badge, verdict and command move into the state card; the lead is dropped (density rule)
- [x] the state badge row at the far right of the h1's row: `Format-GeneralPageHtml -HeadAside`, drawn as the house
  page-header row (`main > header`)
- [x] the description split into paragraphs at each capitals lead-in, the lead-in in bold
  (`ConvertTo-PluginDescriptionHtml`)

### TEST

- [x] `dev-pages.tests.ps1` green (356 passed); the live hub serves the new form
- [ ] the owner's look at /plugins/dkj-solutions (a visible result)

### DEPLOY: feat/plugin-page-side-by-side

A plugin's page on the hub (`/plugins/<name>`) now sets its description and its state on this machine side by
side, as two cards in one row, with its state at the far right of the title's row and the description broken
into paragraphs at each chapter, so it reads on one screen without scrolling.

**Score:** 2

#### What makes this deploy extra special

In every repo's hub, a plugin's page now fits one screen: what the plugin is on the left, whether it is up to
date here (with the command that fixes it) on the right.

**Score:** 2

#### Pull Request

hub: plugin page side by side on one screen

Plugins: dkj-policy

