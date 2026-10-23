## feat/3323-stopwatch-auto

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

The follow-up to #3315 (#3323): the clock times Claude's work without anybody pressing Start or Stop, and the
page only shows the measurements (owner, October 23, 2026).

#### Design

- **The marker is the only way a run starts.** A prompt whose first line begins with `stopwatch:` (any case,
  leading whitespace allowed) starts an Auto run at once, labelled with the rest of that line (cut to the label
  maximum; "Assignment" when empty), with the checkout's HEAD as its `StartHead`. The `UserPromptSubmit` hook
  reads its JSON payload from stdin and only parses the `prompt` field, never prints it. A marked prompt while a
  run is still going DISCARDS that run and starts the new one: with no button left to discard, a run that never
  reached the trunk would otherwise block every later measurement. The empty-HEAD guard holds: with no HEAD
  nothing starts and nothing is discarded. An unmarked prompt does nothing.
- **The stop is "HEAD moved and the checkout is back on the trunk", not "a branch was seen".** A Stop hook fires
  only at the end of a turn, and a whole ship (branch, PR, merge, fold) usually happens inside one turn, so a
  branch is never observed at a turn's end. The `Stop` hook ends the running Auto run only when the checkout is
  on the trunk, `git --no-optional-locks status --porcelain` is empty AND HEAD differs from `StartHead`. That is
  a sign the work landed, not a proof. A turn that only answers a question leaves HEAD alone and the run keeps
  going; a branch parked for the owner's eye is not on the trunk, so it keeps going too.
- **The rules are pure, the hook only gathers.** `Invoke-StopwatchHookEvent` takes runs, branch, clean, HEAD,
  trunk, the prompt and the clock, so every rule is tested without git. `scripts/dashboard/stopwatch-hook.ps1`
  reads the store and (only when a decision needs it) git, writes the store when the decision changed it, prints
  nothing and always exits 0. It never writes over a store that does not read, and keeps a `.bak` of a store that
  holds a run it cannot parse. The trunk name comes from `Get-TrunkBranchName` in `scripts/repo-config.ps1`
  where this repo defines one, else `main`.
- **The pages are read-only, an overview of cards and a page per label.** `/stopwatch` shows the running run
  (label and live clock) and one card per measurement label, in the hub's own card markup: the label, its number
  of runs, the latest run's time, its change against the run before and, for the label going now, its live clock.
  A card links `/stopwatch/<slug>`, the label's page: every run, newest first, with start, duration, the change
  and the transcript phases (time and share), and a link back. A slug is the lower-cased label with other runs of
  characters as one dash (40 characters at most, `run` when nothing is left); labels that would share a slug each
  get a hash suffix of the SHA-1 of the lower-cased label, so they never merge and the slug does not depend on
  the order of the runs; an unknown slug is a 404. The overview opens straight on its Measurements heading: no h1, lead, tiles, Now section or the hub's
  airsquats banner (the page's own opt-out, `-Bare`, on the plugin's `Format-GeneralPageHtml` and this repo's
  `Format-DevPageHtml`, default off, so no other page changes); a going run shows on its card with its live
  clock. The label page is bare too and its trail reads Home, Stopwatch, label (a new `-ParentCrumbs` parameter
  on the same two functions). Every form
  and button is gone, and so are the POST script, the `POST /stopwatch/<action>` route of the server (the
  server takes no POST at all now, so its general 405 answers one), `Invoke-StopwatchAction`, the query parser,
  the arm feature (armed state, `arm` and `disarm`, the armed-prompt rule), manual laps and the laps column, notes
  and delete. A run keeps `Auto` and `StartHead` in the store, which the Stop rule needs.
- **Old stores still read.** Laps, notes and an armed label from an earlier version are ignored on read and
  dropped on the next hook write; an old hand-started run shows as a plain row.
- **Left out on purpose:** the hooks are wired in this repo's `.claude/settings.json` only, so they run for a
  session of this checkout and nowhere else.

### CREATE

- [x] `stopwatch-lib.ps1`: `Auto` and `StartHead` on a run, `New-StopwatchRun`, `Get-StopwatchPromptMarker`,
  `Invoke-StopwatchHookEvent` (the marker starts a run and discards one going; the Stop rule), and the page cut
  down to the measurements; the manual actions, arm, laps, notes and the query parser removed
- [x] `scripts/dashboard/stopwatch-hook.ps1`: the hook script for `UserPromptSubmit` and `Stop`, reading the
  prompt from stdin
- [x] `serve-connector-dashboard.ps1`: the POST route and its same-origin handling removed;
  `dev-pages-lib.ps1`: the card subtitle
- [x] `.claude/settings.json`: the two hook entries, with `"$CLAUDE_PROJECT_DIR/scripts/dashboard/stopwatch-hook.ps1"`
  (wired by the owner)

### TEST

- [x] `stopwatch.tests.ps1`: the marker (label, empty label, later line, case), the hook's decisions (a marked
  prompt starts a run, discards one going, does nothing without a HEAD; an unmarked prompt does nothing; the stop
  only on the trunk, clean and moved, never for an old hand-started run or one without a StartHead), the store
  round trip and an older store, the hook script run for real against stores of its own (prompt on stdin, silent,
  exit 0, a second marker discards, never writes over an unreadable store, a `.bak` for a dropped run), the
  slugs (round trip, collisions, order independence), the overview cards, the label page and the read-only page;
  `connector-dashboard.tests.ps1` runs the real server for the overview, a label page, an unknown slug (404) and a POST (405)
- [x] `dev-pages.tests.ps1` and `connector-dashboard.tests.ps1` green
- [x] `check-plugin-integrity.ps1`: 0 errors

### DEPLOY: feat/3323-stopwatch-auto

The hub's Stopwatch now times Claude's work without anybody pressing Start or Stop. Begin a prompt to Claude with
`stopwatch: <label>` and the clock starts right there (a run still going is discarded); it stops when Claude is
back on the trunk with a clean checkout and HEAD moved since the start, a sign the work landed rather than a
proof of it. A turn that only answers a question, or a branch parked for your look, keeps the clock going. The
`/stopwatch` page only shows the measurements now: the running clock and one card per label (runs, latest time,
change against the run before), and each card opens that label's page with every run, its comparison with the
run before and where its time went. The buttons are gone.

A running hub must be restarted to pick up this code: an old server would write the old shape of the store back.

**Score:** 2

#### What makes this deploy extra special

The hub is this repo's own dev server, so nothing a consumer sees changes. `dkj-policy`'s
`general-pages-lib.ps1` gains two opt-in parameters (`-Bare`, `-ParentCrumbs`) that only the Stopwatch passes; every
page that does not pass them renders byte for byte as before.

**Score:** N/A

#### Pull Request

Stopwatch: a stopwatch: prompt starts a run, the page only shows the measurements
