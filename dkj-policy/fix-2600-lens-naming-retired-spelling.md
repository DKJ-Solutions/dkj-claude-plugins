## fix/2600-lens-naming-retired-spelling

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

#2600: a consumer still holding `<g>-<id>-extension.md` (with no current-spelling lens) had that file
admitted as "unknown vocabulary" by `Get-UnknownLensNameById`, so the missing-lens finding was held
under `[LENS-NAMING]`, which says "NOTHING IN THE REPO NEEDS CHANGING" and prescribes a plugin refresh. For the
retired spelling the opposite holds.

**Reason verified against the tree, not only the symptom:** the Lens row's `AlsoRead` is `@()` (#2292,
`check-report-lib.ps1`), so `Get-SpecialistFileId -Kind Lens` rejects the retired name; no other kind
claims it (guard (a)); `06-24-extension` matches guard (b)'s `^[a-z-]*<id>[a-z-]*$`. The new test run
against `origin/main`'s script confirms it: the marker fires and the exit is 0.

Repair, the issue's second option: a failure of its own naming the `git mv`. The issue's first option
(let the generic "no repo-lens" fire) would prescribe creating a file beside the one holding the content.

### CREATE

- [x] `Get-RetiredLensPath` in `scripts/sync/check-roster-sync.ps1` -- an exact-name probe over the lens
  dir candidates; the missing-lens arm asks it FIRST and prints the rename. No filter was added inside
  `Get-UnknownLensNameById`: with the arm first it could never fire, and the docstring says why.
- [x] Header docstring lists the new finding; plugin mirror in `dkj-subagents-alpha` copied byte-identical.
- [x] Test 11w in `scripts/tests/roster-sync.tests.ps1`: a mixed tree (one current lens, one retired).

### TEST

- [x] `roster-sync.tests.ps1`: 422 pass, 0 fail. Against `origin/main`'s script: 5 of 11w's asserts fail,
  so the test reproduces the defect.
- [x] Review pass. Victor: no bugs; a legacy `.claude/extensions/` case added to 11w. Unquoted `git mv`
  paths and the hard-coded `#2292` left as they are (fixed paths without spaces; history, not a pointer).
  Sebastian: both paths now go through `Format-SafePathToken`, since a candidate lens dir carries a
  directory name off disk into session context. Edith: two PLAN/DEPLOY wordings tightened.

### DEPLOY: fix/2600-lens-naming-retired-spelling

`check-roster-sync` no longer tells a repo whose lens is still named `<g>-<id>-extension.md` that
nothing needs changing. No reader has resolved that spelling since #2292, so the check now reports the
specialist as running without its lens, and prints the `git mv` to the current name (#2600).

**Score:** 2

#### What makes this deploy extra special

If your repo still has a lens file named like `06-24-extension.md`, the session-start check now shows
it as an error with the exact rename to run, instead of a yellow line asking you to update the plugins.
Updating the plugins never fixed that file. Renaming it is what gives that specialist its repo lens back.

**Score:** 2

#### Pull Request

