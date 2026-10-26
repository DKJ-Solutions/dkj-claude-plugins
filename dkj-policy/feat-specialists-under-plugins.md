## feat/specialists-under-plugins

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

The owner (October 26, 2026): the Specialists card on the hub belongs one level deeper, under the
Plugins card. It follows the house style's precedent (#3493): a page about what a plugin ships hangs below
that plugin, so Specialists moves to `/plugins/dkj-subagents-alpha/specialists`, the core team that brings
the specialists.

### CREATE

- [x] `Format-PluginPageHtml` takes `-Cards`, a hub's own pages below a plugin, after what the plugin ships itself
- [x] `Get-PluginHubCards` names Specialists under dkj-subagents-alpha; `Get-RepoHubPages` drops it
- [x] The server serves the page at its new path and sends `/specialists` there with a 303; its trail runs Plugins > dkj-subagents-alpha

### TEST

- [x] `dev-pages.tests.ps1`: 358 passed
- [x] `connector-dashboard.tests.ps1`: 228 passed, the 303 and the new route included

### DEPLOY: feat/specialists-under-plugins

The hub's Specialists page now sits one level below Plugins, at `/plugins/dkj-subagents-alpha/specialists`,
linked as a card from that plugin's page instead of from the home page; `/specialists` sends an old link
there. `Format-PluginPageHtml` takes `-Cards` for a hub's own pages below a plugin.

**Score:** 2

#### What makes this deploy extra special

N/A: the new `-Cards` parameter is optional and unused on the plugin's own general pages server, so a
consumer's hub looks the same.

**Score:** N/A

#### Pull Request

Specialists page under its plugin on the hub
