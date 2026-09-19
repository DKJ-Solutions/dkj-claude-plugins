## feat/2131-subagent-def-filenames

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
> For tier 2 audiences: the subscriber of a service. That reader and nobody else -- what matters only
> inside this repo belongs under the first `**Score:**`. If the change reaches that reader
> not at all, N/A is a complete answer and the common one. **One hop and no further:** where that
> reader is itself a business, ITS own customers sit one hop past this repo and are never the reader
> here -- they take nothing this repo ships. Name the party that runs the upgrade, and score
> against them.
>
> The phase arc, the marks and the whole form: `DEVELOPMENT-portable.md`, which ships
> with this workflow.

### PLAN

Step B of the #2128 rename plan, and the highest-consequence step in the round: the 26 subagent
definitions move to `specialist-NN-NN-subagent.md` and the four `plugin.json` `agents` arrays that
name every one of them literally move with them, in the same commit. #1764 is the precedent for
getting that wrong -- a bad shape there made four of six plugins uninstallable for a whole release.

The suffix change finishes #1698: that rename moved `agents/` to `subagents/` and left the files
inside called `NN-NN-agent.md`.

#### This branch is RED on its own, by design, and #2130 is what makes it green

PR-A (#2130, the dual-name readers) is the step that teaches the thirteen reader sites both
conventions, and the #2128 plan puts it before any file moves. It is claimed and parked with its
plan only, so this branch was built against a trunk that does not yet carry it. Dave's instruction:
build step B now, hold the PR until #2130 has merged.

Measured on this branch, so the next session can tell an expected failure from a new one:

- **the lint gate: 26 error(s), all check 6b** -- one orphan manual per renamed def
  (`no corresponding subagents/<g>-<id>-agent.md`). Nothing else fails: no dead link, no manifest
  finding, no drift.
- **`subagent-shared.tests.ps1`: 4 fails** -- all downstream of the same glob. Its own
  `the gate walked every obliged agent def, not zero of them` assert is what turns the silent
  version of this into a loud one, and it did.
- **check 38 (`[agents-key]`) is GREEN**: 6 plugins read, 26 `agents` entries held to an existing
  `.md` file inside the plugin root, 0 findings. The edit this step exists to get right verifies
  clean on its own.
- **`check-roster-sync.ps1` is unaffected here**, because it reads the installed plugin cache rather
  than this working tree -- which is the channel #2130's dual-name layer exists for, one release
  further on.

#### What this branch deliberately does NOT touch

- **The thirteen reader sites and their mirrors** (`check-plugin-integrity.ps1`,
  `check-roster-sync.ps1` x2, `build-agent-defs.ps1`, `check-consumer-drift.ps1`, `bootstrap.ps1`,
  `sync-roster.ps1` and the docstrings attached to their globs). That is #2130's whole subject, and
  editing it here would be two branches writing the same lines.
- **Each def's prose naming its sibling manual and lens.** #2131 lists it, and the #2128 plan
  sequences the manuals in PR-C and the lenses in PR-D -- so repointing those lines now would name
  files that do not exist yet and turn a green dead-link scan red. Measured while checking: the defs
  carry no reference to their own filename at all, so nothing inside them is stale after the move.
- **The synthetic fixtures** under `scripts/tests/` (`99-99-agent.md`, `01-01-agent.md`,
  `09-91-agent.md` and the rest). They are fixture names, not this repo's files, and they exercise
  readers that must go on recognising the retired convention.
- **`measure-skill.tests.ps1`'s captured CLI output**, which lists `02-09-agent` ... `06-30-agent`.
  It is a recorded run, parsed rather than compared against the tree, and rewriting the names inside
  it would falsify the capture.

### CREATE

- [x] Claim #2131 and cut the branch from a current trunk
- [x] `git mv` all 26 subagent defs to `specialist-NN-NN-subagent.md` -- 15 alpha, 3 ecomm, 5 lifehub, 3 shopify
- [x] Move the four `plugin.json` `agents` arrays in the same commit, and verify all 26 entries resolve to a file on disk
- [x] Follow every reference to a renamed def outside `dkj-policy/releases/**`: `README.md`, `.claude/specialists/README.md`, the 05-15, 06-24 and 06-25 lenses, `plugins/dkj-subagents/README.md`, `subagent-shared/README.md`
- [x] Move the convention where `worktree-lib.ps1` and its `dkj-policy` mirror name it, byte-identically, so the drift lint stays green
- [x] Point `subagent-shared.tests.ps1`'s walk of the REAL tree at the new name -- it is the one suite that enumerates the shipped defs rather than a fixture
- [x] Correct the stale `agents/` directory in the three prose paths that were being rewritten anyway -- #1698 moved that folder and these sentences never followed
- [ ] Merge `main` once #2130 has landed, and resolve whatever it renders stale
- [ ] The #1757 check: no retired name inside the lines this branch ADDS

### TEST

- [ ] Lint gate + all suites green, after #2130 is in

### DEPLOY: feat/2131-subagent-def-filenames

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

The subagent definitions become specialist-NN-NN-subagent.md, with the four plugin.json agents arrays
