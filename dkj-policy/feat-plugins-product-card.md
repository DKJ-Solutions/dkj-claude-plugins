## feat/plugins-product-card

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

The owner asked for a Plugins card on the product port (localhost:4870), its page listing every plugin
this repo offers. A visible result, so the branch waits for the owner's look before it merges.

### CREATE

- [x] `scripts/lib/dev-pages-lib.ps1`: a third product page in `Get-ProductPages`, `Get-MarketplacePluginKind` and `Format-PluginsPageHtml`
- [x] `scripts/dashboard/serve-connector-dashboard.ps1`: `Get-PluginsModel` and the `/plugins` route
- [x] The overview's cards made lean link cards, the detail on `/plugins/<name>` (the owner: the cards were crammed); the page function renamed `Format-MarketplacePluginsPageHtml`, since the hub's lib has a `Format-PluginsPageHtml` of its own
- [x] The four specialist teams share one card, `dkj-subagents`, whose page `/plugins/dkj-subagents` lists them; a team's own page is `/plugins/dkj-subagents/<name>` (the owner)

### TEST

- [x] `dev-pages`, `connector-dashboard`, `logbook`, `stopwatch` and `stopwatch-sync` suites green (every suite loading `dev-pages-lib`), both Plugins levels covered
- [x] `check-house-style.ps1` green
- [ ] The owner has looked at http://localhost:4870/plugins and a plugin's own page

### DEPLOY: feat/plugins-product-card

The product's home page gains a third card, Plugins, and `/plugins` lists every plugin
`.claude-plugin/marketplace.json` ships, one link card each saying its kind, version and whether this repo enables it -- the specialist
teams sharing one card, `dkj-subagents`, with a page of their own -- and
each plugin has its own page under it: what it holds (subagents, personas, skills, hook
commands), its source path, and its full description in paragraphs. It is the tree, read on every request. The
hub's own Plugins page stays what this checkout enables.

**Score:** 2

#### What makes this deploy extra special

N/A -- a page of this repo's own product server, which no consumer runs.

**Score:** N/A

#### Pull Request

A Plugins card on the product's home page, listing every plugin this marketplace ships

