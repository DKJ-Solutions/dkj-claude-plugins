## feat/2653-asana-comment-back

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

Inbound #2653, from `BWJ-Development/xoxowildhearts`, requested by Maikel on September 30, 2026. When
a session makes a GitHub issue from an Asana task, the colleague who filed that task should see it on
the task itself. The requester settled the format after three rejected drafts, by editing the comment
on Asana task 1218346245039866 into the final form:

- the issue link as the **first line** of the task's description, and as the first line of the
  skeleton for a task `report-issue` creates itself;
- one comment on the Asana-origin task, word for word, in English on every board:
  `— New GitHub Issue (automation)`, a blank line, then `GitHub issue <url> is created and in
  development.`

The stage model is not changed: an Asana-origin card still moves to `Filed`. The comment names no
section, so it cannot name the wrong one.

### CREATE

- [x] `report-issue/SKILL.md`: the skeleton's link on top, step 2's two writes for an Asana-origin task, and step 3's comment rule rewritten around them
- [x] `WORKFLOW-portable.md`: the same skeleton change, the fixed comment form beside the carve-out for colleague-filed tickets, and that comment's fixed header named as the exception in the automated-message rule

### TEST

- [x] Nothing parses the notes in skeleton order: `backlog-page-rules.ps1` renders notes verbatim, and `asana-mirror`'s sweep (a) reads a URL anywhere in the notes
- [x] No test pins the text that changed (`grep` over `scripts/tests` and the plugin script trees)
- [x] Gates green through `open-pr`

### DEPLOY: feat/2653-asana-comment-back

`report-issue` now writes back to an Asana task an issue was made from. The issue link goes on the
first line of the task's description, and one comment in a fixed form goes on the task:
`— New GitHub Issue (automation)`, then *"GitHub issue <url> is created and in development."* A task
the skill creates itself now carries `Tracked on GitHub:` as its first line as well.

**Score:** 2

#### What makes this deploy extra special

A colleague who files a request in Asana now sees on the task itself that it has been picked up and
where it is tracked, without opening GitHub.

**Score:** 3

#### Pull Request

report-issue: comment back on the Asana task an issue was made from, and put the issue link at the top of the task
