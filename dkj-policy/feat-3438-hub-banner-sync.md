## feat/3438-hub-banner-sync

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

#3438: the hub banner's airsquats state moves from the browser to the hub servers and a private gist, so a
tick-off on one machine clears the box on every machine and every repo hub. The storage is the owner's choice
(October 25, 2026). The banner is a visible result, so the branch waits for the owner's look before the merge.

### CREATE

- [x] `hub/lib/airsquats-lib.ps1`: the conflict-free state (hours as a union, clearedAt latest-wins), the
  machine's file under a lock, the `/api/airsquats` handler and one gist sync through an injectable gh
- [x] `hub/pages/sync-airsquats.ps1`: the hidden child that syncs, under a lock of its own, gh bounded at 20 s
- [x] `Format-RepoHubBanner`: the page asks its own server and plays the tone when the server says so
- [x] The route in `serve-general-pages.ps1` and `serve-connector-dashboard.ps1`, and the relay on the product
  port (`brandbook/vite.config.ts`)
- [x] `hub/README.md` section "The banner, in sync on every machine"; the house-style README's banner row

### TEST

- [x] `hub-airsquats.tests.ps1` (new, 38 asserts): the merge rule, the hours a poll counts, the API's
  refusals, a gist sync through a fake gh (a second machine included), and a gist as bounded input
- [x] `dev-pages.tests.ps1`: the banner asserts now hold it to the server API instead of localStorage
- [x] Live: a general pages server on a scratch state answered GET 200, a same-site POST 403, a same-origin
  POST 200; one real sync created the private gist and remembered its id
- [x] Review: Victor (the gist search missed the gist among several in 5.1, and read one page only: now
  `gh --paginate --jq`, verified against the real gh; a dying child re-spawned every poll: now throttled by
  the server) and Sebastian (no blocker; remote input now bounded, gist id held to `\z`; the auto-create
  default filed as #3439)
- [x] A second real sync from an empty state found the existing gist and created none
- [x] The lint gate and every suite, through open-pr
- [~] The owner's look at the banner on two machines -- not a step this branch can tick: the PR waits for it

### DEPLOY: feat/3438-hub-banner-sync

The hub banner's airsquats count is now kept by the hub servers instead of each browser: every repo hub on
a machine shares one file, and a private GitHub gist (`dkj-hub-airsquats`) carries it to every other
machine, so ticking the box anywhere clears it everywhere within about half a minute. The page asks
`GET /api/airsquats` and ticks off with `POST /api/airsquats/clear`, the one POST the hub serves, and only
same-origin. The state merges without conflict, and an hour still counts only where a hub saw it begin.

**Score:** 3

#### What makes this deploy extra special

Whoever runs the hub on more than one machine, or with several repo hubs open, now sees one airsquats
count everywhere: tick it off on the laptop and the desktop's box clears too. Machines on the same `gh`
account find the shared gist with nothing configured; machines on different accounts pin it with
`DKJ_HUB_AIRSQUATS_GIST`.

**Score:** 3

#### Pull Request

Hub airsquats banner in sync across machines
