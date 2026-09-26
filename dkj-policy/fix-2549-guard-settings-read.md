## fix/2549-guard-settings-read

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

#2545 guarded the WRITES of bootstrap's two settings proposals; #2549 found the READ that feeds the
merged one still unguarded. Verified by reading: `Test-Path` and `ReadAllText` on `.claude/settings.json`
both follow a reparse point, and every top-level key of the parsed file is copied into `$merged`, which is
then written as a real file inside the repo.

### CREATE

- [x] `bootstrap.ps1`: `Get-WriteReparse` on `$settingsPath` before the read; a reparse point sets `$settingsRefusal` (naming it), so no merged proposal is composed and the annotated one is still offered
- [x] the `[notice]` gives the reason that fits a link (a merge would copy what the link reaches into the repo) instead of the parse-failure reason

### TEST

- [x] `bootstrap-drift.tests.ps1`: a junctioned `.claude/` holding a `settings.json` -- the read is refused and named, nothing is written beside it; a symlinked `settings.json` -- no merged proposal, the annotated one still written (skipped on this machine: no Developer Mode); the #2545 junction case now asserts the read refusal instead of the write refusal (237 asserts green)

### DEPLOY: fix/2549-guard-settings-read

`specialists-init`'s bootstrap no longer reads `.claude/settings.json` through a symlink or junction.
Every key of that file is copied into the merged proposal, `.claude/settings.proposed.json`, a real file
inside the repo, so a `settings.json` linked to a JSON file outside the repo would have carried that
file's content into the tree. #2545 guarded the writes; the read now takes the same check, and a link
there is refused like a file that does not parse: no merged proposal, a `[notice]` naming the link, and
the annotated proposal still offered.

**Score:** 1

#### What makes this deploy extra special

N/A. Adoption tooling does not reach a subscriber of a service.

**Score:** N/A

#### Pull Request

The bootstrap no longer reads settings.json through a symlink or junction

