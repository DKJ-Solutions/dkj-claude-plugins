## feat/3349-stopwatch-shared-runs

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

The owner wants every machine to see every Stopwatch measurement (#3349). They picked a data ref on origin
from three routes: the store cannot become a tracked file, because it would dirty the workflow it times.

#### Measured before building

- GitHub accepts a push to `refs/stopwatch/<id>` and its deletion (a probe ref, pushed and removed again).
- Piping text into a native git call from Windows PowerShell 5.1 prepends a BOM (`git mktree` refused
  `﻿100644 blob ...`), so the lib hashes the blob from a file and writes the tree through a throwaway
  `GIT_INDEX_FILE` instead of feeding `mktree` on stdin.

### CREATE

- [x] `scripts/lib/stopwatch-sync-lib.ps1`: the machine id, the ASCII payload, merge, interval, fetch, read, publish
- [x] `scripts/dashboard/stopwatch-sync.ps1`: fetch, compute this machine's phases, publish; logs its last outcome
- [x] The Stop hook starts the sync in a process of its own once a run has ended, except when a test passes a store
- [x] The hub merges the other machines' runs into both Stopwatch pages, uses their own phases, and starts a throttled sync
- [x] The docstrings and the page footers no longer say the runs stay on this machine

### TEST

- [x] `scripts/tests/stopwatch-sync.tests.ps1` (new, 34 asserts, in the pages group): a publish and a read between
  two clones of a bare origin, an accent through git, the fast-forward, and an untouched index, tree and HEAD
- [x] `stopwatch.tests.ps1` 127/0 and `connector-dashboard.tests.ps1` 202/0, the latter after guarding the sync lib's load
- [x] A real run on this machine: `stopwatch-sync.ps1` pushed `refs/stopwatch/9a3c5423`, and the checkout stayed clean

### DEPLOY: feat/3349-stopwatch-shared-runs

Stopwatch runs are now shared between machines
([#3349](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3349)). Each machine publishes its finished
runs, with the transcript phases it read for them, to a ref of its own on origin, `refs/stopwatch/<machine id>`.
It does that with git plumbing only, so the checkout's index, working tree and branches are never touched, and
in a background process, so no turn and no page load waits on the network. The Stop hook starts that process
once a run has ended. The hub starts it at most every five minutes while a Stopwatch page is open, and it shows
every other machine's runs beside this machine's own, marking them as "another machine". The machine id is
random, so no computer name reaches this public repo. The labels, times and phase names become public.

**Score:** 2

#### What makes this deploy extra special

N/A: the Stopwatch, its hook and the hub are this repo's own tooling under `scripts/`, and no plugin ships them.

**Score:** N/A

#### Pull Request

Stopwatch: share the runs across machines through a ref on origin

