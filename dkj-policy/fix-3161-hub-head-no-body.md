## fix/3161-hub-head-no-body

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

#3161: the repo hub answered a `HEAD` on its non-200 routes with a body, and on its 200 routes with
`Content-Length: 0`. The plugin's `Send-LoopbackResponse` (general pages and placeholder servers) is the
same function with the same flaw, so it is repaired in the same move.

### CREATE

- [x] `Send-DashboardResponse` and `Send-LoopbackResponse` take `-Method` and drop the body on `HEAD`,
  keeping the real `Content-Length`; every call site passes it, and the per-route blanking is gone
- [x] `connector-dashboard.tests.ps1`: the HEAD assert pinned `Content-Length: 0`; it now asserts the real
  length and no body, plus a 404 and a refused 403
- [x] `dev-preview-sessionstart.tests.ps1`: a HEAD gets exactly the GET's head and no body

### TEST

- [x] Both suites green locally (161 and 178 passed)

### DEPLOY: fix/3161-hub-head-no-body

The repo hub and the plugin's general pages and placeholder servers now answer a `HEAD` the way RFC 9110
asks on every route: the same headers a `GET` would get, with the real `Content-Length`, and no body
(#3161). Before, the 403, 405, 404 and restart-503 routes sent their body to a `HEAD`, and the 200 routes
sent `Content-Length: 0`. The body is now dropped once, in the response function, instead of by each route.
Nothing visible changes: browsers do not send `HEAD` for a page load.

**Score:** 1 -- prevents a client that probes with `HEAD` from reading a body it did not ask for or a wrong size; that has not happened.

#### What makes this deploy extra special

N/A -- nothing a user of the plugin notices: the servers are local dev pages, and browsers load them with `GET`.

**Score:** N/A

#### Pull Request

Local dev servers answer HEAD with the real Content-Length and no body on every route

