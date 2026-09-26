## docs/2508-asana-delete-reads-state

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

Inbound #2508: a smartwatchbanden session offered Asana cards for deletion based only on the GitHub
issue's labels, and deleted one the owner had completed and commented on. The six checks hold: nothing
in `dkj-policy-bwj` says anything about deleting a task (grepped `delete_task` / `delet`), the subject
(the ticket chapter) exists, and the proposed repair is one rule beside #2360's gate.

A hook was considered and not built. A PreToolUse hook on `delete_task` sees only the task gid, and it
cannot read the task's state without an Asana credential the session does not hand it. So it could
refuse every delete or none, not the case this issue is about. The rule is the repair the report asks
for.

### CREATE

- [x] `WORKFLOW-portable.md` step 2: a new `####` rule. Read the task's state before offering or
  running a delete. A completed task, or one with a human comment, is unlinked and never deleted.
  Every other offer shows the state beside the title.
- [x] `report-issue` SKILL step 2: "a wrong card is deleted by hand" no longer reads as a licence. It
  points to the rule.

### TEST

- [x] Lint gate via open-pr (`-SkipTests`, per this machine's memory limit; CI runs the suites).

### DEPLOY: docs/2508-asana-delete-reads-state

An agent no longer offers or deletes an Asana task on the strength of the GitHub issue alone
([#2508](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2508)). The ticket chapter now
requires it to read the task first: whether it is completed, whether it has human comments, which
projects it sits in, and who created it. A task that is completed or carries a human comment is never
offered for deletion. The card is unlinked from the issue instead. Every other offer shows that state
beside the title. `report-issue` points to the rule where it used to say that a wrong card is deleted
by hand. This prevents a repeat of the smartwatchbanden case, where a colleague's completed request was
deleted and nobody noticed for two days.

**Score:** 2

#### What makes this deploy extra special

N/A -- a working rule for the agent in a BWJ repo; no subscriber of a service runs anything new.

**Score:** N/A

#### Pull Request

An Asana task is read before it is offered for deletion

