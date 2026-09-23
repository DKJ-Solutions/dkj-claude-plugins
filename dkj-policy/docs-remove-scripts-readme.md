## docs/remove-scripts-readme

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

Dave asked to remove `scripts/README.md` (rarely read, never always-on), safely: move what code and
docs cite it for as a place of record into the owners' lenses, repoint every citation, keep the gates
green.

### CREATE

- [x] Move the source/mirror rules, the `New-ScratchPath` rule and the #1668 leftovers decision to
  Sylvester's lens, and the suite fixture convention to Tycho's lens
- [x] Remove `scripts/README.md`; repoint the root README, the lint docstrings, the guard's printed
  message, the code comments and the two plugin pages
- [x] Regenerate the shared-script mirrors

### TEST

- [x] Lint and test gates via `open-pr`

### DEPLOY: docs/remove-scripts-readme

Removed `scripts/README.md`. The rules and measured decisions that code and docs cited it for now live
in [Sylvester's lens](../.claude/specialists/lenses/specialist-05-15-lens.md#the-scripts-directory-is-the-source)
and [Tycho's lens](../.claude/specialists/lenses/specialist-04-18-lens.md#a-suites-fixture-path-carries-the-pid-and-a-fresh-guid);
the directory map and the entry-point table were dropped, because each skill page and each plugin's
`hooks/hooks.json` already answer them. The source-repo guard's refusal now points at the lens.

**Score:** 1 -- prevents a reader following the guard's printed pointer, or a code comment, to a page
that no longer exists.

#### What makes this deploy extra special

Nothing reaches a subscriber: the only consumer-visible change is wording in two plugin pages.

**Score:** N/A

#### Pull Request

