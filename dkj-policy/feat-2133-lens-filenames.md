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
- [x] Waited for #2130, #2131 and #2132 to land on `main`, then merged `main` in -- 26 conflicts, all of one shape: this branch renamed the lens path and step C renamed the manual path on the same line. Resolved by taking `main`'s file and re-applying the lens rename, so both renames stand
- [x] `check-roster-sync.ps1`: 0 errors, all 30 specialists rostered with a lens -- the four main-loop personas included; `connectors.tests.ps1` green again
- [x] Always-on baseline raised through the gate: 109,391 B -> 109,739 B, the 348 B predicted above, all of it filename
- [x] #1757 check run against `origin/main`: every remaining `-extension.md` on an added line is either this document's own prose about the rename or the `.claude/extensions/` legacy layout, both out of scope by the plan above

### TEST

- [x] Lint gate: `check-plugin-integrity.ps1` -- 0 errors (43 before the release-link repair)
- [x] Test gate on the branch as it stands: 117 of 118 suites green; the one red is `connectors.tests.ps1` ("self-manifest ... exit code 0"), caused by `check-connectors.ps1` still reading `NN-NN-extension.md` -- step A's reader
- [x] Both gates fully green after A, B and C were merged in -- lint 0 errors, all 118 suites passed (851s, 16 lanes)

### DEPLOY: feat/2133-lens-filenames

This repo's 30 repo lenses are now named `specialist-<group>-<id>-lens.md`, and every reference naming one
of them by its real path followed -- 84 files, 316 replacements, plus 43 link targets under
`dkj-policy/releases/**` whose prose is left exactly as written. **No reader moved with it**: step A
(#2130) had already put every one of them behind `Get-SpecialistFileShapes`, so what makes this the
written name is a row in that table and a `git mv`, not a sweep through the scripts.
`check-roster-sync.ps1` reports all 30 specialists rostered with a lens, the four main-loop personas
included -- they carry their id only inside that filename, which is what #2130's lookbehind fix exists
for. Step D of the rename plan in #2128.

The always-on baseline rose 348 B and every byte of it is filename: the path names lens files and each
one is nine bytes longer. Raised through the gate with that reason on the record rather than hand-edited.

**Score:** 3

#### What makes this deploy extra special

**A consumer's subagent defs now name a lens file their own tree does not have yet.** The defs that ship
to every consuming repo tell a specialist to read
`.claude/specialists/lenses/specialist-<group>-<id>-lens.md`, and a consumer who has not renamed still
holds `<group>-<id>-extension.md`. Their lenses are authored content, so nothing here renames them --
`bootstrap.ps1` is additive-only. The parenthetical those defs already carry names the **pre-seam**
`.claude/plugins/<family>/` and `.claude/extensions/` layouts, which is a different thing from the
current seam under its old filename, so it does not cover this.

What closes it is #2134, the migration section in `INSTALL.md`, which lands next and carries the `git mv`
for a consumer's own tree. Until they run it the named lens is simply not found, and the specialist
carries on without one -- no error and no report, the same silence any dead path has here.

**Score:** 4

#### Pull Request

Rename step D: this repo's 30 lenses to specialist-NN-NN-lens.md
