## feat/specialists-page

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

Maikel asked for a hub page listing every specialist, to show how large each one's context is. Four
parts per specialist, each measured in bytes off the tree and estimated in tokens at measure-context-lib's
factor: the listing (a subagent's description, always-on wherever its plugin is enabled), the definition
(the file minus frontmatter: a subagent's system prompt, a persona's body), the manual and this repo's lens.

### CREATE

- [x] `scripts/lib/dev-pages-lib.ps1`: `ConvertTo-SpecialistRow` (pure parse of one definition file) and `Format-SpecialistsPageHtml`; `/specialists` added to the hub's Pages card
- [x] `scripts/dashboard/serve-connector-dashboard.ps1`: `Get-SpecialistsModel` reads the four plugins, the manuals, the lenses and `enabledPlugins`; the route serves it
- [x] The persona h1's em dash is composed from `[char]0x2014`: the Edit tool wrote a typed `—` to disk as the literal character, which 5.1 then read as ANSI (the #2671 trap)

### TEST

- [x] `scripts/tests/dev-pages.tests.ps1`: the hub's seven pages, the row parse (subagent and persona, folded description, frontmatter cut, no lens, unknown shape) and the page (order, tiles, escaping, off-here, always-on, the labelled factor, empty and failed reads); 156 pass, `connector-dashboard.tests.ps1` 127 pass
- [x] Served live on 4875: 30 specialists, 19 enabled here, ~2,267 tokens of listing in every session here, Sylvester's full read the largest at ~143,664
- [x] Victor's and Sebastian's reviews: an empty frontmatter block no longer yields a descending range, and a failed load of measure-context-lib names the fallback factor in the page's warning; escaping and path handling held
- [x] The page is a visible result: Maikel looked and approved it

### DEPLOY: feat/specialists-page

The Repo hub gains a Specialists page: every specialist the dkj-subagents plugins ship, with the context
each one costs -- its always-on listing, its definition, its manual and this repo's lens, in measured
bytes and estimated tokens -- largest first, so an oversized manual or lens shows at a glance.

**Score:** 2

#### What makes this deploy extra special

N/A -- the dev server runs in this repo only; no plugin a consumer installs changes.

**Score:** N/A

#### Pull Request

a Specialists page on the Repo hub -- every specialist and the context each one costs

