## fix/2110-git-path-decoding

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

Force core.quotePath=true + Convert-GitQuotedPath in fold-changelog-entry's tracked/untracked split and find-specialist-mentions' scan set; route the latter through Invoke-NativeCapture.

### CREATE

- [x] `fold-changelog-entry.ps1`: the tracked/untracked `ls-files` read forces `core.quotePath=true`
      and decodes with `Convert-GitQuotedPath`, behind a guarded dot-source of `git-porcelain-lib.ps1`
- [x] `find-specialist-mentions.ps1`: the scan set goes through `Invoke-NativeCapture` with the same
      forced flag and decode, replacing the bare `@(git ls-files 2>$null)` and its `Push-Location` pair
- [x] `build-shared-scripts.ps1` re-run, so the `dkj-policy` mirror of the fold carries the repair

### TEST

- [x] `find-specialist-mentions.tests.ps1`: fixture copy list rebuilt as one closure list (the two new
      dot-sources plus `command-probe-lib`/`run-progress-lib`), a note whose FILENAME carries a
      non-ASCII character added to the fixture, and the deterministic cp850 half plus three source pins
- [x] `fold-changelog.tests.ps1`: four source pins on the repaired call site, since the fold's own
      failure is latent and no fixture it can build reaches the mis-decode
- [x] `fixture-lib-deps.tests.ps1` green -- the gate that holds a fixture copy list against what the
      copied script dot-sources
- [x] Lint gate + full suite via `open-pr`
- [~] A live end-to-end assert on the fold's mis-decode -- dropped: both sides of that comparison are
      branch-document names and `CHANGELOG.md`, and `branch-info.ps1` constrains a branch name to
      ASCII, so the state cannot be produced by the writer. Pinned at the source instead, and the
      dependency is now named in the code

### DEPLOY: fix/2110-git-path-decoding

Two git reads whose answer is a PATH no longer depend on the console code page. `fold-changelog-entry`
splits the paths it is about to commit into tracked and untracked with a `git ls-files` whose output it
then COMPARES -- so a mis-decoded name failed that comparison, dropped out of `git commit -- <paths>`,
and the run printed *"git never tracked them ... the fold deleted them from disk all the same"* about a
file it had just deleted. `find-specialist-mentions` built its whole scan set from a bare
`@(git ls-files 2>$null)`: a mis-decoded name keeps its `.md` tail, passes the extension filter and then
cannot be opened, so the file left the mention scan silently -- the one failure a report whose job is
*"do not miss a place"* must not have. Both now force `core.quotePath=true` and decode with
`Convert-GitQuotedPath`, the repair [`.claude/rules/language-layers.md`](../.claude/rules/language-layers.md)
prescribes and #2109 applied one caller over; the second is routed through `Invoke-NativeCapture` as
well, so its exit code is readable instead of swallowed.

The fold's instance is LATENT today, and it is the only one whose safety rests on a constraint in
another file: both sides of that comparison are branch-document names and `CHANGELOG.md`, which
`branch-info.ps1` holds to ASCII. The code now says so, which it did not before.

**Score:** 2

#### What makes this deploy extra special

N/A -- neither reader reaches a consumer as behaviour. The fold is mirrored into every consumer's
`dkj-policy` cache, but its instance is latent for the reason above, and the mention scan is a
source-repo reporter that never travels.

**Score:** N/A

#### Pull Request

Two more git path readers decode with the console code page

