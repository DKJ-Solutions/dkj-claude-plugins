## feat/update-plugins-all-checkouts

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

Add an -AllCheckouts mode to update-plugins.ps1 that enumerates checkouts from installed_plugins.json, skips any checkout not clean on its trunk, runs the per-checkout update in each, and reports a summary. Then tests, skill page, mirror, ship.

#### Why a mode and not a second skill

Asked for on October 15, 2026 ("make a skill that does this from now on") right after updating all 11
checkouts on this machine by hand. A mode on the existing skill reuses the tested per-checkout run and
adds no always-on skill description; the skill's description now names the "update all repos" request.

#### #1890's boundary, re-read rather than obeyed

The boundary existed for one measured cost: a sweep could leave uncommitted `.claude/settings.json`
diffs in repos nobody opened, possibly on a mid-work branch. The hand run that day left no diff in any
of the 11 checkouts, so the cost is guarded per checkout instead: skip a checkout not on its trunk or
with a dirty `.claude/`, and name any diff the run does leave.

### CREATE

- [x] `scripts/task/update-plugins.ps1`: `-AllCheckouts` -- checkouts from every `projectPath` in the install administration, guards per checkout, one child run each handed its own root (`-RootOverride` + `CLAUDE_PROJECT_DIR`), the source repo on its own copy, a sweep summary; gone folders counted in one line
- [x] the plugin mirror `plugins/dkj-policy/scripts/task/update-plugins.ps1`, byte-identical
- [x] `plugins/dkj-policy/skills/update-plugins/SKILL.md`: description, usage line, boundary section, parameter row

### TEST

- [x] `scripts/tests/update-plugins.tests.ps1` scenarios 17-20, in a fixture path with a space: the sweep runs the clean checkout handed its own root, skips a feature branch, a dirty `.claude/`, a missing origin/HEAD and a clone merely shaped like the source repo (its planted script never runs), counts a gone folder; `-DryRun` runs nothing; `-RootOverride` is refused; a failed child run is named and exits 1 -- 109 pass, 0 fail
- [x] review: Victor (no correctness bug; the `.claude/` probe now fails closed), Sebastian (a checkout's own copy runs only for an unmodified source-repo origin; the git-config trust is documented), Edith (the old boundary prose qualified as the default run)
- [x] live `-AllCheckouts -DryRun` on this machine: 10 checkouts run, this checkout skipped on its feature branch, 6 gone-folder records counted

### DEPLOY: feat/update-plugins-all-checkouts

`update-plugins` takes a new `-AllCheckouts` switch that runs the update in every checkout on the
machine holding a plugin install record, in one command. The checkouts are read off
`~/.claude/plugins/installed_plugins.json`, so no folder list is kept. A checkout that is not on its
trunk, or that has uncommitted changes under `.claude/`, is skipped, so a mid-work branch is never
touched ([#1890](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/1890)'s concern). Each
checkout is handed its own root explicitly, because a session's `CLAUDE_PROJECT_DIR` would otherwise
send every child run to the session's repo. Records whose folder is gone are counted in one line.

**Score:** 3

#### What makes this deploy extra special

Updating the plugins in every repo on a machine is now one command instead of one run per repo:
`update-plugins.ps1 -AllCheckouts`, or ask for "update all repos". Repos on a feature branch or with
uncommitted `.claude/` changes are skipped and listed, and `-DryRun` shows every command first.

**Score:** 3

#### Pull Request

update-plugins -AllCheckouts: update every checkout on this machine in one run
