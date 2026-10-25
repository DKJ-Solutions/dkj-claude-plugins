## feat/3439-airsquats-gist-opt-in

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

#3439, decided by the owner on October 25, 2026: option 2 -- the hub creates the airsquats gist only on an
opt-in (`DKJ_HUB_AIRSQUATS_GIST=auto`); without it the banner syncs across the repo hubs of one machine only.

### CREATE

- [x] `Get-AirsquatsGistSetting` reads the opt-in (off / auto / pinned id / invalid); `Start-AirsquatsSync`
  starts no child when it is off, and `Sync-AirsquatsGist` calls no gh and writes nothing then, refuses an
  invalid value as `syncError`, and keeps a pinned id to that gist alone
- [x] The docstrings of `airsquats-lib.ps1`, `sync-airsquats.ps1`, `serve-general-pages.ps1` and the hub
  README say the gist is an opt-in

### TEST

- [x] `hub-airsquats.tests.ps1`: unset calls no gh, writes nothing and starts no child; an invalid value calls
  no gh and is reported; the existing sync cases run under `auto`; a pinned gist that cannot be read is an
  error, never a search or a new gist (44 passed, 0 failed)

### DEPLOY: feat/3439-airsquats-gist-opt-in

The hub's airsquats gist is now an opt-in. With `DKJ_HUB_AIRSQUATS_GIST` unset, the hub servers start no
sync child, call no `gh` and write nothing to the logged-in GitHub account: the banner agrees across the
repo hubs of one machine only. `auto` finds the `dkj-hub-airsquats` gist, or creates it, private, as #3438
did by default; a gist id pins that gist; any other value syncs nothing and reports it as `syncError`. This
replaces #3438's "with nothing configured", which never reached a release.

**Score:** 2

#### What makes this deploy extra special

Whoever runs the hub gets the cross-machine airsquats sync only after setting `DKJ_HUB_AIRSQUATS_GIST` to
`auto` (or to a shared gist id) in the `env` block of their own `~/.claude/settings.json`. Without it, no
gist is created on their GitHub account.

**Score:** 2

#### Pull Request

Hub airsquats sync: the gist only on an opt-in

