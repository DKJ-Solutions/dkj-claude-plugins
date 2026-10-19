## fix/hub-static-after-restart-check

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

Measured October 19, 2026: the hub on port 4876 had been started at 19:16 the day before, before #3130
moved the house style into the plugin and before #3122 taught the server to restart on a moved HEAD.
It looked for `house-style.css` where its own code kept it, `ReadAllBytes` threw, and the browser got a
dropped connection rather than a stylesheet. #3122 closes that for every server started since, except
that a static file skips the restart check by design, so a file that moved still dropped the connection.

The skip itself stays: a 503 handed to a `<link>` would leave the page it styles unstyled, and the
reload of `/` already triggers the restart.

### CREATE

- [x] `serve-connector-dashboard.ps1`: a static file that is there is served before the check, as before;
      a missing one falls through to the restart check, and is a plain-text 404 when HEAD has not moved
- [x] Stopped the five pre-#3122 hub servers on ports 4871-4874 and restarted 4876 (machine state, not in
      the diff)

### TEST

- [x] `connector-dashboard.tests.ps1` group 4: the fixture now holds the stylesheet and not the theme
      script; a missing file is a 404 before the move, a present one skips the check after it, a missing
      one restarts the server, and the page's own 503 is asserted on a third move against the successor
      -- 161 passed, 0 failed

### DEPLOY: fix/hub-static-after-restart-check

A hub server whose stylesheet or theme script has moved out from under it no longer drops the
connection. A missing static file now falls through to the moved-HEAD check, so a server on older code
restarts itself onto the checkout's, and where the checkout has not moved it answers a plain 404 naming
the file. A file that is there is still served without the check, so a page is never left unstyled by a
503.

**Score:** 2

#### What makes this deploy extra special

N/A -- the Repo hub server is this repo's own development tool and ships to no consumer.

**Score:** N/A

#### Pull Request

a hub server restarts when a static file it serves has moved, instead of dropping the connection

