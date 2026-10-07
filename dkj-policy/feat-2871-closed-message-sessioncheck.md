## feat/2871-closed-message-sessioncheck

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

Inbound #2871: smartwatchbanden never copied the `asana-closed-message` workflow and has no
`ASANA_PAT`, so since the asana-mirror retirement no closed or reopened message has posted there, and
nothing said so. Verified on pickup: no hook, check or gate in the tree compares a store's copy with
the template. The fix is a SessionStart check in `bwj-development` itself (the plugin the store
already loads), not the connector check: that one runs in the source repo and reads registry data,
while the two files and the secret are only readable from the store.

#### Design

- Silent outside `smartwatchbanden` and `xoxowildhearts` (the origin's repo name), the only repos adopt
  step 1 copies into.
- Three findings: a copy missing, a copy that differs from the template (line endings normalised), and
  no `ASANA_PAT` among the repo and organisation secrets. A secret list that cannot be read is not
  evidence of a missing secret, so that finding then stays out.
- Always exit 0; an `[ERROR]` line per finding, the form this family forwards.

### CREATE

- [x] `hooks/closed-message-sessioncheck.ps1` and its SessionStart registration in `hooks/hooks.json`.
- [x] `README.md`'s hooks row and `adopt-bwj-development` step 1 name the check.

### TEST

- [x] `scripts/tests/closed-message-sessioncheck.tests.ps1`: 12 asserts, covering the measured case,
  a stale copy, a CRLF copy, an unreadable secret list and silence outside the stores.
- [x] `check-plugin-integrity.ps1`: 0 errors.

### DEPLOY: feat/2871-closed-message-sessioncheck

`bwj-development` gains a SessionStart check, `closed-message-sessioncheck`
([#2871](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2871)). In `smartwatchbanden` and
`xoxowildhearts` it reports three things. The first is an `asana-closed-message` workflow or script that
was never copied. The second is a copy that differs from the template the installed plugin ships. The
third is an `ASANA_PAT` secret that is not visible to the repo. Before this, a store that skipped
`adopt-bwj-development` step 1 lost every closed and reopened message on its Asana tasks without a
word. It is silent in every other repo, and also when it cannot read the secret list.

**Score:** 3

#### What makes this deploy extra special

After the update, a session in a store whose closed-message workflow is missing or outdated, or has no
`ASANA_PAT`, says so at start, and names the `adopt-bwj-development` step that repairs it. The same line
appears after a later template change (such as #2870) until the store takes the new copy.

**Score:** 3

#### Pull Request

bwj-development: a session check reports a store whose asana-closed-message copy is missing, stale, or has no ASANA_PAT

