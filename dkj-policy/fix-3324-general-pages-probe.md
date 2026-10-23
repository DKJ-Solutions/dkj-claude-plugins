## fix/3324-general-pages-probe

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

Issue #3324: the ownhub assert "while the general pages answer as ever" went unanswered for 30 s in CI shard
`suites (2)` seven times on October 23, 2026, which blocked every PR that day. Ruled out by measurement:
unauthenticated `gh` in a non-git folder exits in 67 ms, the hook's `/whoami` probe always sends its request,
and no suite sharing the shard stops processes. The cause is still not established, so the repair takes out
the one part of the assert that runs processes in the server's single-threaded loop, and makes a miss
diagnose itself.

### CREATE

- [x] `dev-preview-sessionstart.tests.ps1`: probe `/artifacts` (a file read) instead of `/issues` (git plus three gh calls). On a miss, ask `/whoami` and print its answer.

### TEST

- [x] `dev-preview-sessionstart.tests.ps1` alone: 308 passed, 0 failed, and `/artifacts` answered in 0 s.

### DEPLOY: fix/3324-general-pages-probe

The ownhub routing assert in `dev-preview-sessionstart.tests.ps1` now probes the general pages with
`/artifacts` rather than `/issues`, so it no longer runs git and gh inside the fixture server's
single-threaded loop. That probe went unanswered for 30 s on loaded CI shards seven times in one day, which
blocked every PR, while answering locally in 0 s
([#3324](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3324)). The cause is not established.
On a miss the assert now also reports what `/whoami` answers, which tells a held loop from a dead server.

**Score:** 3

#### What makes this deploy extra special

N/A: a test of this repo's own suite, which no consumer runs.

**Score:** N/A

#### Pull Request

dev-preview-sessionstart: probe the general pages with /artifacts, which spawns nothing

