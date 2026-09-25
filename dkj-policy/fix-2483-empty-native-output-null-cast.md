## fix/2483-empty-native-output-null-cast

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

A [string] cast of an empty native-command result is $null under Windows PowerShell 5.1, so every .Trim() on one throws; the first preview push of a branch hit it.

### CREATE

- [x] Replace every `([string](<git read>)).Trim()` in the three shipped Shopify scripts
  (push-preview x6, sweep-preview-themes x1, sync-main x2) with `"$(<git read>)".Trim()`, mirrors synced
  byte-identical. The report named two sites; the consumer's follow-up comment named four; the grep
  found nine, of which five (the `git config --get`, `rev-parse --verify --quiet` and `merge-base`
  reads) can actually print nothing -- the four `rev-parse HEAD` reads are repaired for consistency.

### TEST

- [x] Reproduced the reason on 5.1.26100: `[string]` of an empty `git config --get` is `$null`.
- [x] `push-preview.tests.ps1` pins the idiom in two halves -- an empty interpolated read trims to `''`,
  and no shipped script still trims a `[string]`-cast native read. Verified the guard matches the
  pre-fix source (it would have been red).

### DEPLOY: fix/2483-empty-native-output-null-cast

`push-preview` no longer crashes on Windows PowerShell 5.1 on a branch's first preview push
([#2483](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2483)). Under 5.1 a `[string]`
cast of a git read that prints nothing is `$null`, not `''`, so the `.Trim()` on the remembered theme id
threw before anything was printed -- on exactly the lazy-creation path the script exists for, with no
workaround for a new branch. Every such read in the three shipped Shopify scripts now interpolates
instead, and a suite assert refuses the old idiom coming back.

**Score:** 4

#### What makes this deploy extra special

N/A -- a store's own customers never see a preview push.

**Score:** N/A

#### Pull Request

push-preview no longer crashes on PS 5.1 when a git read prints nothing

