## fix/3657-product-server-restart-after-trunk-move

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

After a /clear the product port still served the code from before the session-start trunk sync (#3657,
measured: the product started at 19:30:23, the trunk fast-forwarded at 19:30:24). Two causes: the
dispatcher's trunk sync and the dev-preview hook are separate SessionStart entries that race, and a
product that survives a /clear is reused whatever moved under it. The owner asked for both to be
automatic on every /clear.

### CREATE

- [x] sessioncheck-dispatch marks the session's prep done in the session cache (Set-SessionPrepDone)
- [x] dev-preview starts the hub first, then waits up to 20 s for that mark before it starts or reuses the product
- [x] dev-preview restarts a product it started itself when HEAD moved after that server was created, and the line says so; a server started by hand is reused as before

### TEST

- [x] session-cache-lib, dev-preview-sessionstart and sessioncheck-dispatch suites green, with unit asserts for the mark and the outdated-server rule and an end-to-end restart after a commit
- [x] Live on this checkout: without a mark the real hook waits out its bound, with one it goes straight on (1.3 s); the product on 4871 serves the Marketplace card

### DEPLOY: fix/3657-product-server-restart-after-trunk-move

The dev-preview hook no longer hands out a product that serves stale code. On every session start, `/clear`
included, it starts the toolbox first and then waits (up to 20 s) for the dispatcher's trunk sync to finish
before it starts or reuses the product. A product the hook itself started before HEAD last moved (a trunk
sync or a checkout) is stopped and started again on its port, and the line reads `(restarted: the checkout
moved after it started)`. A server somebody started by hand is reused as before.

**Score:** 2

#### What makes this deploy extra special

In every repo with a product port, a merge pulled in by the session-start sync now shows up on that port
right after `/clear`, without restarting the server by hand.

**Score:** 2

#### Pull Request

dev-preview restarts a product server older than the trunk sync
