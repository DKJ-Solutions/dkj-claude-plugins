## feat/2999-asana-body-html-notes

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

Inbound #2999: the colleague-facing Asana skeleton is sent as plain `notes` and renders as one dense
block. Send it as `html_notes` with bold labels and blank lines, keep the four headings and their
order, and keep the issue URL the first line for every reader of it.

Readers of that first line, checked: `guard-asana-mirror` scans the whole tool input for an issue URL
(the `href` carries it); `build-backlog-page` reads the plain `notes` Asana derives from `html_notes`,
so the link text stays the full URL rather than the issue's example `<owner>/<repo>#<n>`;
`asana-link-pickupcheck` reads the issue body, not the task.

### CREATE

- [x] `report-issue` step 2: the skeleton as `html_notes`, bold labels, blank lines, escaping rule
- [x] `report-issue` step 2, the prepend path: same styled first line, always through `html_notes`
- [x] `WORKFLOW-portable.md`: the skeleton's shape and a pointer to the skill for the markup

### TEST

- [x] No other copy of the old `What is wrong:` / `How urgent:` skeleton in the tree (grep)

### DEPLOY: feat/2999-asana-body-html-notes

An Asana task that `report-issue` creates now reads as four separate sections instead of one dense
block. The body is sent as `html_notes`, with each label in bold on its own line and a blank line
between sections. The issue link is a real link, and it stays the first line. A colleague's own
ticket gets the same styled link on top, always written through `html_notes` so their formatting
survives
([#2999](https://github.com/DKJ-Solutions/dkj-claude-plugins/issues/2999)).

**Score:** 3

#### What makes this deploy extra special

A BWJ store maintainer sees the difference on the first card filed after the update. Colleagues who
read the board get labelled, spaced sections where they used to get four run-together lines.

**Score:** 3

#### Pull Request

report-issue: send the Asana task body as html_notes with bold labels and spacing

