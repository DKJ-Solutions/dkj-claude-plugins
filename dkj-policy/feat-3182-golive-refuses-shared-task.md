## feat/3182-golive-refuses-shared-task

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

Inbound #3182 from smartwatchbanden: follow-up #919 was linked to umbrella #911's Asana task at the
close, and its closed message told the requester the task was in review while #911 was still open.
Verified: `asana-link-pickupcheck` already names a task linked from two open issues (#2928), but only at
`claim-issue`/`new-branch`, and a link added at the close never passes a pickup; `build-golive-block`
asked nothing. So the close side asks the same rule (`Get-AsanaTaskCoClaimants`), and
`WORKFLOW-portable.md` states that a follow-up or sub-issue does not take its umbrella's link. The close
guard (a hook with a time budget) is left as it is: the post is where the block, and so the message, is
made. Proposal 1 said "warn, or refuse without -Force"; it refuses the post, like the link check beside it.

### CREATE

- [x] `build-golive-block.ps1`: searches the open issues for the task where the block leaves the
  console, warns on `-OutFile`, refuses `-Post` without `-Force`; a failed search only warns
- [x] `WORKFLOW-portable.md`: the rule, under one issue per ticket; `golive-block` skill: the `-Force` row

### TEST

- [x] `bwj-development.tests.ps1`: 755 pass (the rule is loaded, not copied; the search is off the
  print-only path; the refusal before the comment; a failed search does not refuse)
- [x] A print-only driver run is unchanged
- [x] The full gate runs in `ship-pr`

### DEPLOY: feat/3182-golive-refuses-shared-task

`build-golive-block.ps1 -Post` now refuses while another open issue links the same Asana task, and names
that issue: the closed message says "this Asana task is now in review", and posted from a follow-up or
sub-issue it would say so while the umbrella is still open. `-OutFile` warns, `-Force` posts regardless,
and `WORKFLOW-portable.md` states that a follow-up or sub-issue does not take its umbrella's task link
(#3182).

**Score:** 2

#### What makes this deploy extra special

A BWJ requester no longer hears that their task is in review because a follow-up closed while the issue
that actually answers their request is still open.

**Score:** 2

#### Pull Request

build-golive-block refuses a post while another open issue links the same Asana task

