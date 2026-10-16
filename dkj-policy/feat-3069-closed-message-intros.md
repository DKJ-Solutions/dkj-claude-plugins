## feat/3069-closed-message-intros

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

Inbound #3069 (Maikel, October 16, 2026), built to its last comment, which supersedes the body and the
three comments before it: the closed message's intro follows where the Asana task goes.

### CREATE

- [x] `asana-closed-message` template: one intro for every completed close, a second line per form (live, after the release, research), and the cancelled intro for the on-hold close
- [x] `Get-AsanaReleaseBlockMarker` in `asana-task-lib.ps1` plus its template copy; `build-golive-block` puts it on a block without `-LiveSince`
- [x] `Get-PasteBlockSections` (lib and copy) drops the closed line's second line with the intro
- [x] `golive-block-rules.ps1`: the block's closed line is the intro plus its second line, in the result and the research block
- [x] `golive-block` skill page and `WORKFLOW-portable.md`: the three closes side by side, and `-Research` only when nothing changed

### TEST

- [x] `bwj-development.tests.ps1`: the moved asserts follow the new wording, and new cases cover the after-release line, the marker on a planned block only, the section reader on old and new blocks, and a full run with an after-release block (679 asserts pass)

### DEPLOY: feat/3069-closed-message-intros

In `bwj-development`, the message a closed issue posts on its Asana task now opens with where the
task goes ([#3069](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3069)). Every close as
completed opens with *"GitHub issue owner/repo#n is now **closed**: this Asana task is now in
review."*. Only the line under it differs:

- a visible change invites a reopen, as before;
- a block that names a planned release day (no `-LiveSince`) says the result becomes visible with
  that release. `build-golive-block` marks such a block with
  `<!-- asana-paste-block-kind: after-release -->`;
- a research close says *"Nothing has changed. Read the outcome below."*, replacing #3017's *"the
  Asana task is ready for review"*.

The not-planned on-hold close opens with *"this Asana task has been cancelled, because there is not
enough information to start development."*. It never says "in review". The `golive-block` skill and
`WORKFLOW-portable.md` now say `-Research` is only for when nothing changed on the store or in the
repo, so a store-admin act that is already live takes the go-live form with `-LiveSince`.

**Score:** 3

#### What makes this deploy extra special

A BWJ store maintainer takes the new `asana-closed-message.ps1` through `adopt-bwj-development`, and
their colleagues read the new intros on the next close. Blocks posted before this version carry no
after-release marker, so they keep the plain reopen line.

**Score:** 3

#### Pull Request

bwj-development: closed messages open with the task's destination; -Research only when nothing changed

