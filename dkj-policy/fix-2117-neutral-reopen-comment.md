## fix/2117-neutral-reopen-comment

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

The reopen comment told the requester the work is being worked on again and to hold off testing. The
workflow cannot know either, and both are false when the ticket goes back to the requester. Replace
with text that asserts only what the workflow knows.

#### What the inbound report measured

Three Asana tasks were mirrored into `smartwatchbanden` as development work, built, merged and
reported as delivered. They were not ours to build -- all three belonged to a colleague and were
still in his A/B-test stage. The work was reverted and the three GitHub issues reopened so the
tickets went back to him, and `asana-mirror` then posted on each card:

> GitHub issue BWJ-Development/smartwatchbanden#696 has been reopened: it is being worked on again,
> so hold off on testing.

The colleague reads the card, not the issue. In order, his card carried the *built and ready to
test* update, then this reopen line, and only then the hand-written correction saying it was
reverted and his again. The automated line contradicts the correction **and outranks it**, because
it carries the authority of the system while the correction is one person's comment.

#### Which of the two shapes, and why the other is declined

The report offered two. **Shape 1, neutral text, is what lands.** It says only what the workflow
knows, so it asserts nothing a later comment has to retract.

**Shape 2, label-driven text** -- let the `NeedsInfoLabel` seam choose between *back with the
requester* and *being worked on again* -- is declined on two grounds, and the first is decisive:

1. **It would not have fixed the measured case.** No `needs-info` label was set on those three
   issues; they were simply reopened. The label-absent branch still asserts *being worked on
   again*, so all three cards get the same false sentence.
2. **It contradicts the script's own stated design.** `Invoke-EventMode` carries the rule in
   capitals -- *a label event moves the card and says nothing* -- because narrating a label would
   put a comment on the submitter's ticket every time somebody triaged it. Letting that same label
   choose the wording of a comment is the same signal speaking on the card by another route.

The mechanism for shape 2 does exist (`$link.Labels` is in hand before the comment is built), so
this is a decision and not a refusal for want of a seam.

### CREATE

- [x] The reopen comment in `New-MirrorComment` asserts only the state change
- [x] BOTH docstrings in that file stop stating the assumption as fact -- `New-MirrorComment`'s
      and the `-Mode event` parameter help twenty lines above it, which Victor caught after the
      first tick had already been made on a step worded as though there were one
- [x] `asana-mirror.yml`'s dropped-reopen argument stops citing the old wording
- [x] `WORKFLOW-portable.md` and `README.md` describe what the comment now says

### TEST

- [x] The suite pins the new contract, so restoring the old sentence fails
- [x] `scripts/tests/dkj-policy-bwj.tests.ps1` green -- 362 asserts
- [ ] The full gate green (lint + every suite), via `open-pr`

### DEPLOY: fix/2117-neutral-reopen-comment

**Score:**

#### What makes this deploy extra special

**Score:**

#### Pull Request

asana-mirror's reopen comment no longer asserts why the issue was reopened

