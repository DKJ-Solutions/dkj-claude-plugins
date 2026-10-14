## feat/3006-research-kind-label

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

A third kind label, `research`, beside `bug` and `feature` in bwj-development, for a research, test or decision ticket that changes nothing on the store. The created form in Asana says *now in progress* instead of *now in development*, so it reads true on such a ticket (Dave, mid-session: one form with new wording, not a second form). The reopened form in asana-closed-message is left as it is.

### CREATE

- [x] WORKFLOW-portable.md: the kind table, the third-kind paragraph, the CRO line, the created form, the Github Type mapping
- [x] report-issue: description, the create command, the kind table, the Github Type mapping, the created form
- [x] adopt-bwj-development step 4: check and create `research`; README seam line

### TEST

- [x] Doc-only change: no script reads the kind labels (grep for the labels and `Github Type` in *.ps1 finds none); the gates run in open-pr

### DEPLOY: feat/3006-research-kind-label

In `bwj-development`, an issue now has three kinds: `bug`, `feature` and `research`. `research` is for a research, test or decision ticket that changes nothing on the store, which used to be filed as a `feature`. It fills the Asana `Github Type` field as `Task`, and `adopt-bwj-development` creates the label beside the other two. The created message on the Asana task now reads *"this Asana task is now in progress"* instead of *"now in development"*, so it is true on a research ticket too ([#3006](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/3006)).

**Score:** 2

#### What makes this deploy extra special

A BWJ store needs the `research` label before a session can file with it: `gh issue create` refuses a label the repo does not have. Re-running step 4 of `adopt-bwj-development` creates it. Requesters see *in progress* on new Asana tasks.

**Score:** 2

#### Pull Request

bwj-development: a research kind label, and the created form says in progress

