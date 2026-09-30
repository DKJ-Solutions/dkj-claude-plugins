## feat/2656-asana-automation-comments

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

#2656 fixes three Asana comments word for word, one per GitHub event: CREATED (posted by
`report-issue`'s session, replacing #2653's form), CLOSED and REOPENED (posted by the CI mirror).
The requester's text shows the issue name as a link and the whole comment in italics, so the comments
are posted as `html_text`. The CI used to post plain `text`, which would have shown a markdown link
literally.

#### Decisions taken on the way

- **The close update loses its pull-request list and its "tick it off yourself" line.** The form has
  neither. Every "no code path completes the task" guarantee is unchanged.
- **The not-planned close keeps its meaning** under the CLOSED header in the same one-sentence shape.
  #2656 names no form for it.
- **The reopen now names a cause ("back in development")**, which reverses #2117's no-guess rule. It
  is the requester's explicit wording, and WORKFLOW-portable says what it costs.
- **De-duplication is untouched.** Asana stores the plain text of an `html_text` comment, and it
  still opens with `GitHub issue <ref> is closed`. A test parses the html and holds its InnerText
  equal to the plain form.
- **The CREATED form is still posted only on a task that came from Asana**, as #2653 scoped it. A
  task `report-issue` creates itself sits in `Filed`, so "now in development" would be false there.

### CREATE

- [x] `asana-mirror.ps1`: `Get-MirrorCommentHeader -Event`, `New-MirrorComment` in the three forms,
      `New-MirrorCommentHtml`, and `New-AsanaCommentRequest -Html`. Both comment writers now post html.
- [x] `report-issue` step 2 carries the CREATED form and how to post it
- [x] WORKFLOW-portable (the step-2 form, the header rule, the step-4 event table, the reopen
      paragraph) and README follow
- [~] Is the change visible in the frontend / storefront? Dropped: this repo has no storefront. The
      comments land in Asana, and their text is pinned word for word by the suite.

### TEST

- [x] `dkj-policy-bwj.tests.ps1`: exact-string asserts for all three forms, not-planned, the marker,
      well-formed html whose InnerText is the plain form, XML escaping, and the skill's copy of the
      CREATED form. 488/488 green in the lane.

### DEPLOY: feat/2656-asana-automation-comments

Every Asana comment the BWJ ticket flow writes now uses one of three fixed forms, in italics with the
issue as a link: *"— GitHub Issue CREATED / CLOSED / REOPENED (automation)"* and one sentence. The
close update no longer lists the closing pull request, and a reopen now says the task is back in
development.

**Score:** 3

#### What makes this deploy extra special

A store takes the CI half by copying the new `templates/asana-mirror.ps1` over its
`.github/scripts/asana-mirror.ps1`. The CREATED comment comes with the plugin update itself.

**Score:** 3

#### Pull Request

The three Asana automation comments in their fixed form

