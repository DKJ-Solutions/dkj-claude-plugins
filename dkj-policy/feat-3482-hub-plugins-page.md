## feat/3482-hub-plugins-page

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

Add a Plugins card and a /plugins General page to the hub: every plugin enabled in the repo, with plugin-versions' verdict per plugin, so a problem with a plugin is visible there.

### CREATE

- [x] `plugin-versions.ps1 -Json` (root copy and plugin mirror): the same rows as one JSON line, plus each plugin's description, whether its install folder is still on disk, and the clones consulted
- [x] `hub/lib/plugins-page-lib.ps1`: reads that line in a bounded child process; the overview is a card per plugin, problems first, as compact as the Stopwatch's, and each plugin has its own page on `/plugins/<name>` with what is wrong, the command, its description and the clone (the owner, October 25, 2026)
- [x] The Plugins card in `Get-GeneralPages` with its icon, the `/plugins` route in the plugin's general server and in this repo's own hub (served from this tree, like `/test-gate`)
- [x] Docs: the hub README, the plugin-versions skill page

### TEST

- [x] `dev-pages.tests.ps1`: the model, the status per verdict code, the overview (a card each, problems first, compact, escaping, empty and failed states), the routing and one plugin's page, and the two card counts on the home page
- [x] `plugin-versions.tests.ps1`: scenarios 20j-20l for `-Json`
- [x] Served live by this hub: the overview with three cards, and each plugin's page

### DEPLOY: feat/3482-hub-plugins-page

Every repo's hub gains a **Plugins** card
([#3482](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3482)). Its page lists every plugin the
repo enables as a card of its own, which opens that plugin's page: the version installed for this checkout, the one
the marketplace clone holds, and what is wrong with the command that closes it. Problems come first: a plugin behind its clone or not installed here,
an install folder gone from disk, a stale clone, a retired name. The verdicts are the `plugin-versions` skill's
own, through its new `-Json` mode, so the page and the skill never disagree.

**Score:** 3

#### What makes this deploy extra special

N/A

**Score:** N/A

#### Pull Request

Hub: a Plugins page listing every enabled plugin and its problems
