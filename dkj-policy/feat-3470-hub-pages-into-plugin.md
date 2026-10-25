## feat/3470-hub-pages-into-plugin

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

Every repo running dkj-policy gets the Stopwatch, Logbook and Test gate cards on its hub, instead of only this source repo.

#### How the issue's six questions were answered

1. **A store per repo**, keyed by the main checkout's folder name and a hash of its path (`Get-HubRepoKey`; a
   `worktree-lane` lane and a Claude Code worktree count as the repo they were cut from), under
   `%LOCALAPPDATA%\dkj-claude-plugins\repos\<repo>-<hash>\`. The name alone was the first draft; the security
   review showed two unrelated repos in folders of one name would share a store, and with sharing on publish each
   other's labels. The machine-wide store of before is taken over by the
   source repo alone (`Move-HubTimingLegacyStore`): its name must be `dkj-claude-plugins` AND it must carry
   `plugins\dkj-policy\hub`. Both, because a test fixture carries the plugin tree under another folder name, and
   measured on this branch, a fixture checkout called `src` took this machine's real stores as its own. They were
   moved back by hand, the rule now needs the key too, and the fixture servers get stores of their own.
2. **Sharing is an opt-in**: `DKJ_STOPWATCH_SHARE=1` in the env block of a repo's `.claude/settings.json`, beside
   `DKJ_RUN_STEP_LOG`, which the hooks, the sync and the hub server all inherit, so the plugin's server never has
   to load a repo's `repo-config.ps1`. Whether a repo is private is not detected: that needs the network, and a
   hook must not wait on it. This repo opts in, so nothing changes here.
3. **The trunk** is still read through `Get-TrunkBranchName`, now with dkj-policy's own `command-probe-lib.ps1`,
   and falls back to `main` where a repo has no seam.
4. **Step marks and transcripts** need nothing new: `stopwatch-lib.ps1` loads dkj-policy's own
   `run-progress-lib.ps1`, and the transcript dir is per checkout already.
5. **The order of the move**: this repo keeps wiring the hooks in `.claude/settings.json`, now at their plugin
   paths in this tree, until the release that ships them reaches its sessions. Both copies firing on one event is
   made harmless rather than avoided: each hook takes a per-store named mutex (`Get-HubTimingLock`), so the second
   reads the first one's write, so a repeated Stop or Logbook Prompt does nothing and a repeated marked Prompt
   replaces the run with one started moments later. Dropping the repo wiring is #3473.
6. **The Test gate in a consumer** shows an empty state naming `scripts/tests/suite-durations.json`. Not built:
   the seam for another path, and moving the writer and the `measure-suites` skill, both because the writer
   reads this repo's own CI shape. Filed as #3474, for the owner's decision.

#### The shape

The libs, hooks, sync and hide scripts and the `stopwatch-hide` skill moved into the plugin by `git mv`, and
the Test gate's three functions into `hub/lib/test-gate-lib.ps1`. Both servers answer the Stopwatch's and the
Logbook's routes through one router, `Resolve-HubTimingPage` in `hub/lib/timing-pages.ps1`, so the rules of which
path is a page, a redirect or a 404 are written once. This repo's own hub still serves all three pages itself,
and its Test gate keeps the suite selection only this repo has.

### CREATE

- [x] Move the Stopwatch and Logbook libs, hooks, sync and hide scripts and the `stopwatch-hide` skill into
      `plugins/dkj-policy/`
- [x] Make the stores one per repo, take the old store over in the source repo only, and make sharing an opt-in
- [x] Serialise the hooks per store, so a repo that wires them itself beside the plugin records one run
- [x] Wire the hooks in `hooks/hooks.json`, and point this repo's own wiring at the plugin paths in this tree
- [x] Move the Test gate's page into `hub/lib/test-gate-lib.ps1`, with an empty state and the repo's own CI link
- [x] Serve `/test-gate`, `/stopwatch` and `/logbook` on the plugin's server, through one router shared with this
      repo's hub, and list the three in `Get-GeneralPages`
- [x] Update the hub README, the skill page and the servers' headers

### TEST

- [x] `stopwatch`, `stopwatch-sync`, `logbook`, `dev-pages`, `connector-dashboard` and `dev-preview-sessionstart`
      suites green, with new asserts for the per-repo key, the guarded takeover, the opt-in, the lock and the
      Test gate's empty state
- [x] `check-plugin-integrity.ps1`: 0 errors
- [x] The real store folder on this machine is unchanged by a full run of the suites once the fixtures have
      stores of their own

### DEPLOY: feat/3470-hub-pages-into-plugin

The Test gate, the Stopwatch and the Logbook are now pages of every repo's hub, served by the `dkj-policy`
plugin, where until now only this source repo had them
([#3470](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3470)). The plugin's `UserPromptSubmit` and
`Stop` hooks record the runs in a store per repo on each machine, and this repo's existing runs are taken over as
its own. A repo shares its Stopwatch runs with its other machines only where it sets `DKJ_STOPWATCH_SHARE=1`,
which this repo does. Both hub servers answer the timing pages through one router in the plugin, and the
`stopwatch-hide` skill ships with the plugin too.

**Score:** 3

#### What makes this deploy extra special

Every repo's hub gains three cards: Test gate, Stopwatch and Logbook. A prompt whose first line begins with
`stopwatch:` is timed until Claude is back on the trunk, and every session that starts on a clean trunk is logged
by itself, with each run's time split into its phases on its own page. The runs stay on the machine unless the
repo opts in with `DKJ_STOPWATCH_SHARE=1`. The Test gate shows an empty state until the repo has a
`scripts/tests/suite-durations.json`; the plugin ships no writer for it yet (#3474).

**Score:** 3

#### Pull Request

Stopwatch, Logbook and Test gate move into the dkj-policy hub
