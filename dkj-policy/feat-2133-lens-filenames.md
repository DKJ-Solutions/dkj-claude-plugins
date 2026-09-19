## feat/2133-lens-filenames

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

Step D of the rename plan in #2128: .claude/specialists/lenses/NN-NN-extension.md becomes specialist-NN-NN-lens.md, with every reference to them following.

#### Ordering: the PR waits for A, B and C

Dave, September 19, 2026: work starts now, but **no PR is opened until steps A (#2130), B (#2131) and C (#2132) are done.** D depends on A in particular -- the roster check and `check-connectors.ps1` are still anchored to the old filename until the dual-name readers land, so this branch cannot be green on its own before then.

#### Scope decisions taken while doing it

- Swept: every reference that names one of THIS repo's own lenses by its real path. Not swept: reader scripts and their mirrors (step A), test fixtures (they prove the old name still reads), the `.claude/extensions/` and `.claude/plugins/<family>/` legacy layouts, and the generic convention text (`<group>-<id>-extension.md`) in agent defs and manuals -- that states the consumer-facing convention and belongs with the migration docs (step E).
- `dkj-policy/releases/**`: prose untouched, but 43 link TARGETS repaired, because check 4 scans that folder and the issue's "Done when" needs the lint gate green. Precedent: `17149edb` did the same for the `dkj-policy` rename.
- The always-on baseline is regenerated through the gate, never hand-edited: the path grows 348 B from longer filenames alone.

### CREATE

- [x] `git mv` the 30 lenses to `specialist-NN-NN-lens.md`
- [x] Sweep the references that name a lens of this repo (84 files, 316 replacements) and the one bare mention in the specialists handbook
- [x] Repair the 43 dead link targets in `dkj-policy/releases/**`
- [ ] Wait for #2130, #2131 and #2132 to land on `main`, then merge `main` into this branch
- [ ] Re-check `check-roster-sync.ps1` reports all 30 specialists rostered with a lens (34 errors today, all from the A readers), and that `connectors.tests.ps1` is green again
- [ ] Raise the always-on baseline through `check-always-on-budget.ps1 -Raise -Reason ...`, on the merged state
- [ ] Run the #1757 check on the added lines against `origin/main`

### TEST

- [x] Lint gate: `check-plugin-integrity.ps1` -- 0 errors (43 before the release-link repair)
- [x] Test gate on the branch as it stands: 117 of 118 suites green; the one red is `connectors.tests.ps1` ("self-manifest ... exit code 0"), caused by `check-connectors.ps1` still reading `NN-NN-extension.md` -- step A's reader
- [ ] Both gates fully green after A, B and C are merged in

### DEPLOY: feat/2133-lens-filenames

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

Rename step D: this repo's 30 lenses to specialist-NN-NN-lens.md

