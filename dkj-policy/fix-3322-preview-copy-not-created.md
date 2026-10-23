## fix/3322-preview-copy-not-created

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

Inbound #3322: at the theme ceiling, `push-preview.ps1`'s duplicate of live exits 0 with no id, the theme
list answers without the name, and the script still says the copy "WAS created" and to re-run. Verified in
the script: the "WAS created" message fired whether or not the list answered. Repair: tell the two cases
apart, report the count from that same list (the ceiling is plan-dependent, #1965), keep stderr on the
duplicate so the CLI's own limit line comes through, and clear `previewFill` where nothing was created.

### CREATE

- [x] `Get-DuplicateMissingIdVerdict` in `preview-theme.ps1`: `no` when the list answered without the name, `unknown` only when it could not be read
- [x] `push-preview.ps1` step 4: duplicate keeps stderr, the list counts as answered only once parsed, `previewFill` is cleared on a failed or absent copy
- [x] Root mirrors of both files synced byte-identical

### TEST

- [x] `push-preview.tests.ps1`: ten new asserts on the verdict, 141 green; `push-preview.ps1` parses clean

### DEPLOY: fix/3322-preview-copy-not-created

When a preview copy of live is not created, `push-preview` now says so instead of saying it WAS created
([#3322](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3322)). With no id returned and the theme
list answering without the name, it reports NOT created, the store's theme count from that list and whatever
the CLI said, and clears the branch's `previewFill=pending`. Only when the list itself could not be read does
it still say the outcome is unknown and to re-run. The duplicate call now keeps stderr, so the CLI's
"A shop may only have N themes" line reaches the operator.

**Score:** 2

#### What makes this deploy extra special

A store at its theme limit no longer sends you into a re-run loop: `push-preview` says the copy was not
created, how many themes the store holds, and that a spent preview has to go first.

**Score:** 2

#### Pull Request

push-preview no longer says a copy of live WAS created when nothing was

