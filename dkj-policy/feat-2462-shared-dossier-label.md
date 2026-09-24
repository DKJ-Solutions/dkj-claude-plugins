## feat/2462-shared-dossier-label

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

Dave ruled on #2462's open decision (September 24, 2026): `dossier` is a shared way of working, so it
ships in the plugin. It joins the existing `Get-TriageLabels` seam beside the four rungs, which needs no
new contract record, and the handling rule goes on `CONTRIBUTING-portable.md` step 1.

### CREATE

- [x] `dossier` (`5319E7`) added to `$script:TriageLabels` in `scripts/repo-config.ps1` and to
  `adopt-triage-labels.ps1`'s built-in fallback, both copies
- [x] Contract record text (Returns/Default) updated in both copies of `script-contract-lib.ps1`; blueprint regenerated
- [x] Handling rule on `CONTRIBUTING-portable.md` step 1; a pointer section in Derek's lens; the scripts README row

### TEST

- [x] `adopt-triage-labels.tests.ps1` and `repo-config.tests.ps1` updated to five labels, both green
- [x] Live run here: `Done: all 5 canonical triage label(s) already exist`

### DEPLOY: feat/2462-shared-dossier-label

`adopt-triage-labels` now prints a `gh label create` line for `dossier` next to the four `prio-N` rungs.
A dossier is a collecting issue: every instance of one recurring problem goes onto it as a comment, and
only the repair of the root cause closes it. `CONTRIBUTING-portable.md` now has the rule for handling
one: a new instance is a comment, a partial repair writes `part of #<n>` with no closing keyword, and the
issue closes only when the root cause is fixed.

Tier 0 is scored for a session filing or repairing against a recurring problem. Until now the label had
no definition in the tree.

**Score:** 2

#### What makes this deploy extra special

N/A. It is a label definition and a tracker convention, and nothing reaches a subscriber.

**Score:** N/A

#### Pull Request

