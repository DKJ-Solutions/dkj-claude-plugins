## fix/3163-hub-uses-loopback-lib

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

#3163: the repo hub kept its own copies of the request reader, the response writer and the Host and
cross-site refusals that the plugin's `loopback-server-lib.ps1` ships, so #3161 had to repair the same
defect twice. The hub already loads `general-pages-state.ps1` from the plugin tree, so it can load this
lib the same way.

### CREATE

- [x] `serve-connector-dashboard.ps1` dot-sources `loopback-server-lib.ps1` and drops `Read-DashboardRequest`,
  `Send-DashboardResponse` and `$MaxHeadBytes`; `connector-dashboard-lib.ps1` drops `Test-DashboardHost`
  and `Test-DashboardCrossSite`
- [x] The static-file 404 that landed after #3161 now passes `-Method` too
- [x] `connector-dashboard.tests.ps1` asserts the Host and cross-site rules against the shared functions

### TEST

- [x] `connector-dashboard.tests.ps1` green locally (163 passed), its fixture server included

### DEPLOY: fix/3163-hub-uses-loopback-lib

The repo hub server now loads the plugin's `loopback-server-lib.ps1` for reading a request, writing a
response and the Host and cross-site refusals, instead of keeping its own copy of each (#3163). #3161
had to repair the same `HEAD` defect in both copies. A fix to any of those rules now reaches the hub and
the plugin's two servers at once. The static-file 404 added after #3161 also stops sending a body to a
`HEAD`.

**Score:** 1 -- prevents a fix to a loopback rule landing in one server and not the other; #3161 nearly did.

#### What makes this deploy extra special

N/A -- the hub is this repo's own server; the plugin's lib only gains a line in its synopsis.

**Score:** N/A

#### Pull Request

Repo hub server loads the plugin's loopback-server-lib instead of its own copy

