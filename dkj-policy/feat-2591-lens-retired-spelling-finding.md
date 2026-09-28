## feat/2591-lens-retired-spelling-finding

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

Close #2591. #2292 retired the `<g>-<id>-extension.md` lens spelling, so the `[LENS-RETIREMENT]`
roll-up in check 7 of `scripts/sync/check-connectors.ps1` answers a question that has been settled. Its
*not yet* arm can no longer fire, and its green ending invites a retirement already performed. The
owner chose to **repurpose** it (decision on the issue, September 28, 2026): report a lens still named
in the retired spelling, because no reader resolves it any more.

#### Scope

- Per connector: `[ERROR]` for a retired-spelling lens with no current-spelling lens for the same id
  (the lens is lost in effect), `[INFO]` for one beside a current copy (dead weight only).
- Remove the roll-up, its `-ConnectorsRootOverride` test seam, and `Get-SpecialistNamingState`, which
  nothing calls any more.
- Out of scope, filed as #2600: `check-roster-sync`'s `[LENS-NAMING]` marker tells a consumer on the
  retired spelling that nothing needs changing.

### CREATE

- [x] Replace check 7's per-connector block with the retired-spelling finding, remove the roll-up, the
  `-ConnectorsRootOverride` parameter and `$seenConnectors`/`$lensNaming`, and rewrite the docstring.
- [x] Remove `Get-SpecialistNamingState` and its tests from `check-report-lib`, update the
  `Get-SpecialistFileShapes` banner, and mirror the lib into its three plugin copies
  (`build-shared-scripts.ps1`).
- [x] Rewrite `connectors.tests.ps1` section 14 for the new check, under `-Manifest`: written only,
  retired only, a mix across ids, both spellings for one id, look-alike names, and no old marker.
- [x] Rewrite the `connectors/README.md` section and add the check to the list at the top of *The check*.

### TEST

- [x] `connectors.tests.ps1` 417 pass, 0 fail; `check-report-lib.tests.ps1` 386 pass, 0 fail.
- [x] A real register sweep on this machine reports no retired-spelling lens in any checkout here. Its
  5 errors are the known xoxowildhearts plugin-enable ones. The full gate runs through `open-pr`.

### DEPLOY: feat/2591-lens-retired-spelling-finding

`check-connectors` check 7 now reports a consumer lens still named `<g>-<id>-extension.md`. It is an
error when that specialist has no current-spelling lens, because since #2292 no reader loads the old
name and the lens is silently gone. It is a note when a current copy sits beside it. The
`[LENS-RETIREMENT]` roll-up that led up to the retirement is removed, which closes
[#2591](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2591).

**Score:** 2

#### What makes this deploy extra special

A repo that keeps a lens under the old name now gets a red line at session start with the `git mv`
that fixes it, where before its specialist quietly ran without that lens. All six registered consumers
are already over, so this reaches nobody we know of.

**Score:** 1

#### Pull Request

check-connectors reports a lens under the retired spelling instead of the retirement roll-up
