## docs/2360-asana-task-only-with-reach-label

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

Inbound #2360. Verified before repairing: `report-issue` step 2 creates the Asana task unconditionally,
and nothing reads step 1's reach decision; the `asana-mirror` CI template creates no tasks at all, so the
repair is procedure text only, as the report said. Built without the proposed seam: the rule is BWJ's
and no repo has asked for the old behaviour, so a seam would be a question nobody is asking.

### CREATE

- [x] `WORKFLOW-portable.md` section 2: the rule, its reason, the measurement, and the two cases it leaves
  alone (a ticket from Asana already has a card; an issue gaining the label later is mirrored then)
- [x] `report-issue` SKILL.md: the description, step 2's gate, step 4's report for a GitHub-only issue,
  and the note that adding the label afterwards means running steps 2-3

### TEST

- [x] Gates via `open-pr -GatesOnly`

### DEPLOY: docs/2360-asana-task-only-with-reach-label

`report-issue` created a colleague-facing Asana task for every issue it filed, although step 1 had just
decided whether a colleague would notice the finding at all. Now only an issue carrying the reach label
gets a card; a tier-0 issue stays GitHub-only, and the report says so, so the missing card reads as a
decision. A ticket that came from Asana keeps its card, and an issue that gains the label later is
mirrored at that moment. The rule is stated in `WORKFLOW-portable.md` section 2.

**Score:** 2

#### What makes this deploy extra special

A BWJ store's board stops receiving cards for developer-only findings after the next plugin update: four
such cards were open in `smartwatchbanden` on the day the rule was written, one of them for a
comment-only fix whose card forced its pull request to ship without resolving the issue. Colleagues see
fewer cards, and every card that remains is one they can check in a preview.

**Score:** 3

#### Pull Request

report-issue: only an issue carrying the reach label gets an Asana task

